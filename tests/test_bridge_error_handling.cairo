#[cfg(test)]
mod tests {
    use starknet::{ContractAddress, contract_address_const};
    use starknet::testing::{set_caller_address, set_block_timestamp};
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    
    use crate::contracts::mock_bridge_adapter::{MockAtomiqBridgeAdapter, MockTestHelpersDispatcher, MockTestHelpersDispatcherTrait};
    use crate::interfaces::bridge_adapter::{IAtomiqBridgeAdapterDispatcher, IAtomiqBridgeAdapterDispatcherTrait};
    use crate::types::{BridgeStatus, BitFlowError};

    const USER: felt252 = 'user';
    const RECIPIENT: felt252 = 'recipient';

    fn setup() -> (IAtomiqBridgeAdapterDispatcher, MockTestHelpersDispatcher) {
        let contract = declare("MockAtomiqBridgeAdapter").unwrap().contract_class();
        let constructor_calldata = array![];
        
        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let bridge = IAtomiqBridgeAdapterDispatcher { contract_address };
        let mock_helpers = MockTestHelpersDispatcher { contract_address };
        
        (bridge, mock_helpers)
    }

    #[test]
    fn test_network_failure_recovery() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        
        // Simulate network failure during lock
        mock_helpers.set_should_fail_lock(true);
        
        set_caller_address(contract_address_const::<USER>());
        
        // First attempt should fail
        let result = std::panic::catch_unwind(|| {
            bridge.lock_bitcoin(amount, recipient, 'tx_hash_1');
        });
        assert(result.is_err(), 'Should fail due to network error');
        
        // Recover from network failure
        mock_helpers.set_should_fail_lock(false);
        
        // Second attempt should succeed
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, 'tx_hash_2');
        assert(bridge_tx_id == 1, 'Should succeed after recovery');
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Confirmed, 'Should be confirmed');
    }

    #[test]
    fn test_partial_failure_isolation() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient1 = contract_address_const::<'recipient1'>();
        let recipient2 = contract_address_const::<'recipient2'>();
        
        set_caller_address(contract_address_const::<USER>());
        
        // First transaction succeeds
        let tx_id_1 = bridge.lock_bitcoin(amount, recipient1, 'tx_hash_1');
        assert(bridge.get_bridge_status(tx_id_1) == BridgeStatus::Confirmed, 'First tx should succeed');
        
        // Simulate failure for second transaction
        mock_helpers.set_should_fail_lock(true);
        
        let result = std::panic::catch_unwind(|| {
            bridge.lock_bitcoin(amount, recipient2, 'tx_hash_2');
        });
        assert(result.is_err(), 'Second tx should fail');
        
        // First transaction should remain unaffected
        assert(bridge.get_bridge_status(tx_id_1) == BridgeStatus::Confirmed, 'First tx should remain confirmed');
        assert(bridge.get_wrapped_bitcoin_balance(recipient1) > 0, 'First recipient should have balance');
    }

    #[test]
    fn test_bridge_failure_with_refund() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        
        set_caller_address(contract_address_const::<USER>());
        
        // Create successful transaction first
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, 'tx_hash');
        
        // Check initial state
        let initial_balance = bridge.get_wrapped_bitcoin_balance(recipient);
        assert(initial_balance > 0, 'Should have wrapped Bitcoin');
        
        // Simulate bridge failure
        let success = bridge.handle_bridge_failure(bridge_tx_id, 'bitcoin_network_down');
        assert(success, 'Failure handling should succeed');
        
        // Check that transaction is marked as failed
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Failed, 'Should be failed');
        
        // Check that refund was processed
        let final_balance = bridge.get_wrapped_bitcoin_balance(recipient);
        assert(final_balance > initial_balance, 'Should have refunded balance');
    }

    #[test]
    fn test_unlock_failure_recovery() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_address = 'bitcoin_addr';
        
        // Add wrapped Bitcoin balance for testing
        mock_helpers.add_wrapped_bitcoin_balance(recipient, amount);
        
        set_caller_address(recipient);
        
        // Configure unlock to fail
        mock_helpers.set_should_fail_unlock(true);
        
        // First unlock attempt should fail
        let success = bridge.unlock_bitcoin(1, amount, bitcoin_address);
        assert(!success, 'Unlock should fail');
        
        // Balance should remain unchanged
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == amount, 'Balance should be unchanged');
        
        // Recover from failure
        mock_helpers.set_should_fail_unlock(false);
        
        // Second attempt should succeed
        let success2 = bridge.unlock_bitcoin(1, amount, bitcoin_address);
        assert(success2, 'Unlock should succeed after recovery');
        
        // Balance should be reduced
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == 0, 'Balance should be reduced');
    }

    #[test]
    fn test_verification_failure_handling() {
        let (bridge, mock_helpers) = setup();
        let bitcoin_tx_hash = 'test_tx_hash';
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        
        // Configure verification to fail
        mock_helpers.set_should_fail_verification(true);
        
        // Verification should fail
        let is_valid = bridge.verify_bitcoin_transaction(bitcoin_tx_hash, amount, recipient);
        assert(!is_valid, 'Verification should fail');
        
        // Recover verification
        mock_helpers.set_should_fail_verification(false);
        
        // Verification should now succeed
        let is_valid2 = bridge.verify_bitcoin_transaction(bitcoin_tx_hash, amount, recipient);
        assert(is_valid2, 'Verification should succeed after recovery');
    }

    #[test]
    fn test_conversion_failure_scenarios() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, 'tx_hash');
        
        // Configure conversion to fail
        mock_helpers.set_should_fail_verification(true);
        
        // Bitcoin to wBTC conversion should fail
        let success = bridge.process_bitcoin_to_wbtc_conversion(bridge_tx_id, 3);
        assert(!success, 'Conversion should fail');
        
        // wBTC to Bitcoin conversion should also fail
        let success2 = bridge.process_wbtc_to_bitcoin_conversion(bridge_tx_id, 'bitcoin_tx');
        assert(!success2, 'Reverse conversion should fail');
        
        // Recover conversion capability
        mock_helpers.set_should_fail_verification(false);
        
        // Conversions should now succeed
        let success3 = bridge.process_bitcoin_to_wbtc_conversion(bridge_tx_id, 3);
        assert(success3, 'Conversion should succeed after recovery');
    }

    #[test]
    fn test_retry_mechanism() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, 'tx_hash');
        
        // Simulate failure
        bridge.handle_bridge_failure(bridge_tx_id, 'network_timeout');
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Failed, 'Should be failed');
        
        // Retry the transaction
        let retry_success = bridge.retry_bridge_transaction(bridge_tx_id);
        assert(retry_success, 'Retry should succeed');
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Pending, 'Should be pending after retry');
        
        // Now process successfully
        let process_success = bridge.process_bitcoin_to_wbtc_conversion(bridge_tx_id, 3);
        assert(process_success, 'Processing should succeed after retry');
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Confirmed, 'Should be confirmed');
    }

    #[test]
    fn test_timeout_handling() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        
        // Set initial timestamp
        set_block_timestamp(1000);
        
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, 'tx_hash');
        
        // Transaction should be pending initially
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Confirmed, 'Mock confirms immediately');
        
        // Simulate it being pending for timeout test
        mock_helpers.simulate_status_change(bridge_tx_id, BridgeStatus::Pending);
        
        // Fast forward time beyond timeout
        set_block_timestamp(1000 + 3700); // More than 1 hour
        
        // Cancel timed out transaction
        let cancel_success = bridge.cancel_timed_out_transaction(bridge_tx_id);
        assert(cancel_success, 'Timeout cancellation should succeed');
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Cancelled, 'Should be cancelled');
    }

    #[test]
    fn test_multiple_failure_recovery_cycles() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        
        set_caller_address(contract_address_const::<USER>());
        
        // Cycle through multiple failure and recovery scenarios
        for i in 0..3 {
            // Configure failure
            mock_helpers.set_should_fail_lock(true);
            
            // Attempt should fail
            let result = std::panic::catch_unwind(|| {
                bridge.lock_bitcoin(amount, recipient, format!("tx_hash_{}", i).as_bytes());
            });
            assert(result.is_err(), format!('Attempt {} should fail', i));
            
            // Recover
            mock_helpers.set_should_fail_lock(false);
            
            // Should succeed after recovery
            let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, format!("tx_hash_success_{}", i).as_bytes());
            assert(bridge_tx_id == i + 1, format!('Success attempt {} should work', i));
        }
        
        // Check final state
        assert(mock_helpers.get_lock_call_count() == 3, 'Should have 3 successful locks');
        let expected_balance = (amount - (amount * 100) / 10000) * 3; // 3 transactions minus fees
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == expected_balance, 'Final balance should be correct');
    }

    #[test]
    fn test_error_state_consistency() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, 'tx_hash');
        
        // Record initial state
        let initial_wrapped_balance = bridge.get_wrapped_bitcoin_balance(recipient);
        let initial_total_locked = bridge.get_total_locked_bitcoin();
        
        // Simulate failure
        bridge.handle_bridge_failure(bridge_tx_id, 'consistency_test');
        
        // Check that state is consistent after failure
        let post_failure_wrapped = bridge.get_wrapped_bitcoin_balance(recipient);
        let post_failure_locked = bridge.get_total_locked_bitcoin();
        
        // After failure handling, wrapped balance should be restored
        assert(post_failure_wrapped > initial_wrapped_balance, 'Wrapped balance should be restored');
        
        // Transaction should be marked as failed
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Failed, 'Status should be failed');
        
        // Retry and check consistency again
        bridge.retry_bridge_transaction(bridge_tx_id);
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Pending, 'Status should be pending after retry');
        
        // Process successfully
        bridge.process_bitcoin_to_wbtc_conversion(bridge_tx_id, 3);
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Confirmed, 'Status should be confirmed');
    }

    #[test]
    fn test_concurrent_failure_handling() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient1 = contract_address_const::<'recipient1'>();
        let recipient2 = contract_address_const::<'recipient2'>();
        
        set_caller_address(contract_address_const::<USER>());
        
        // Create multiple transactions
        let tx_id_1 = bridge.lock_bitcoin(amount, recipient1, 'tx_hash_1');
        let tx_id_2 = bridge.lock_bitcoin(amount, recipient2, 'tx_hash_2');
        
        // Fail both transactions
        bridge.handle_bridge_failure(tx_id_1, 'failure_1');
        bridge.handle_bridge_failure(tx_id_2, 'failure_2');
        
        // Both should be failed
        assert(bridge.get_bridge_status(tx_id_1) == BridgeStatus::Failed, 'TX1 should be failed');
        assert(bridge.get_bridge_status(tx_id_2) == BridgeStatus::Failed, 'TX2 should be failed');
        
        // Retry one transaction
        bridge.retry_bridge_transaction(tx_id_1);
        
        // Only the retried transaction should be pending
        assert(bridge.get_bridge_status(tx_id_1) == BridgeStatus::Pending, 'TX1 should be pending');
        assert(bridge.get_bridge_status(tx_id_2) == BridgeStatus::Failed, 'TX2 should remain failed');
        
        // Process the retried transaction
        bridge.process_bitcoin_to_wbtc_conversion(tx_id_1, 3);
        assert(bridge.get_bridge_status(tx_id_1) == BridgeStatus::Confirmed, 'TX1 should be confirmed');
        assert(bridge.get_bridge_status(tx_id_2) == BridgeStatus::Failed, 'TX2 should remain failed');
    }
}