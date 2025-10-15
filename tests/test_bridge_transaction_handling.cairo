#[cfg(test)]
mod tests {
    use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
    use starknet::testing::{set_caller_address, set_block_timestamp};
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    
    use crate::contracts::atomiq_bridge_adapter::AtomiqBridgeAdapter;
    use crate::contracts::mock_bridge_adapter::{MockAtomiqBridgeAdapter, MockTestHelpersDispatcher, MockTestHelpersDispatcherTrait};
    use crate::interfaces::bridge_adapter::{IAtomiqBridgeAdapterDispatcher, IAtomiqBridgeAdapterDispatcherTrait};
    use crate::types::{BridgeStatus, BitFlowError};

    const OWNER: felt252 = 'owner';
    const USER: felt252 = 'user';
    const RECIPIENT: felt252 = 'recipient';
    const AUTHORIZED_CONTRACT: felt252 = 'authorized';

    fn setup_real_bridge() -> IAtomiqBridgeAdapterDispatcher {
        let contract = declare("AtomiqBridgeAdapter").unwrap().contract_class();
        let constructor_calldata = array![
            OWNER,
            1000000_u256.low.into(), 1000000_u256.high.into(), // exchange rate
            10000_u256.low.into(), 10000_u256.high.into(),     // minimum amount
            100_u256.low.into(), 100_u256.high.into()          // fee rate
        ];
        
        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        IAtomiqBridgeAdapterDispatcher { contract_address }
    }

    fn setup_mock_bridge() -> (IAtomiqBridgeAdapterDispatcher, MockTestHelpersDispatcher) {
        let contract = declare("MockAtomiqBridgeAdapter").unwrap().contract_class();
        let constructor_calldata = array![];
        
        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let bridge = IAtomiqBridgeAdapterDispatcher { contract_address };
        let mock_helpers = MockTestHelpersDispatcher { contract_address };
        
        (bridge, mock_helpers)
    }

    #[test]
    fn test_bitcoin_to_wbtc_conversion_success() {
        let bridge = setup_real_bridge();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        // Create a bridge transaction
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        // Initially should be pending
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Pending, 'Should be pending');
        
        // Authorize a contract to process conversions
        set_caller_address(contract_address_const::<OWNER>());
        // Note: We need to add authorize_contract as a public function for testing
        
        // Process conversion with sufficient confirmations
        set_caller_address(contract_address_const::<AUTHORIZED_CONTRACT>());
        let success = bridge.process_bitcoin_to_wbtc_conversion(bridge_tx_id, 3);
        
        assert(success, 'Conversion should succeed');
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Confirmed, 'Should be confirmed');
    }

    #[test]
    fn test_bitcoin_to_wbtc_insufficient_confirmations() {
        let bridge = setup_real_bridge();
        let amount = 100000000; // 1 BTC - requires 6 confirmations
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        // Process with insufficient confirmations
        set_caller_address(contract_address_const::<AUTHORIZED_CONTRACT>());
        let success = bridge.process_bitcoin_to_wbtc_conversion(bridge_tx_id, 3); // Only 3 confirmations
        
        assert(!success, 'Should fail with insufficient confirmations');
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Pending, 'Should remain pending');
    }

    #[test]
    fn test_wbtc_to_bitcoin_conversion() {
        let bridge = setup_real_bridge();
        let lock_amount = 100000;
        let unlock_amount = 50000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'lock_tx_hash';
        let bitcoin_address = 'bitcoin_addr';
        let unlock_bitcoin_tx_hash = 'unlock_tx_hash';
        
        // First lock some Bitcoin
        set_caller_address(contract_address_const::<USER>());
        bridge.lock_bitcoin(lock_amount, recipient, bitcoin_tx_hash);
        
        // Now unlock from recipient's perspective
        set_caller_address(recipient);
        let unlock_bridge_tx_id = bridge.unlock_bitcoin(1, unlock_amount, bitcoin_address);
        
        // Process the wBTC to Bitcoin conversion
        set_caller_address(contract_address_const::<AUTHORIZED_CONTRACT>());
        let success = bridge.process_wbtc_to_bitcoin_conversion(unlock_bridge_tx_id, unlock_bitcoin_tx_hash);
        
        assert(success, 'wBTC to Bitcoin conversion should succeed');
        assert(bridge.get_bridge_status(unlock_bridge_tx_id) == BridgeStatus::Confirmed, 'Should be confirmed');
    }

    #[test]
    fn test_bridge_failure_handling_lock_operation() {
        let bridge = setup_real_bridge();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        // Create a bridge transaction
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        // Check initial wrapped Bitcoin balance
        let fee = (amount * 100) / 10000; // 1% fee
        let expected_wrapped = amount - fee;
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == expected_wrapped, 'Wrong initial wrapped balance');
        
        // Handle bridge failure
        set_caller_address(contract_address_const::<AUTHORIZED_CONTRACT>());
        let success = bridge.handle_bridge_failure(bridge_tx_id, 'bitcoin_network_error');
        
        assert(success, 'Failure handling should succeed');
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Failed, 'Should be failed');
        
        // Check that wrapped Bitcoin was refunded
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == 0, 'Wrapped Bitcoin should be refunded');
        
        // Check that total locked Bitcoin was reduced
        assert(bridge.get_total_locked_bitcoin() == 0, 'Total locked should be reduced');
    }

    #[test]
    fn test_bridge_failure_handling_unlock_operation() {
        let (bridge, mock_helpers) = setup_mock_bridge();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_address = 'bitcoin_addr';
        
        // Add wrapped Bitcoin balance directly for testing
        mock_helpers.add_wrapped_bitcoin_balance(recipient, amount);
        
        // Create unlock transaction
        set_caller_address(recipient);
        let unlock_bridge_tx_id = bridge.unlock_bitcoin(1, amount, bitcoin_address);
        
        // Check that wrapped Bitcoin was burned
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == 0, 'Wrapped Bitcoin should be burned');
        
        // Simulate failure in unlock process
        mock_helpers.simulate_status_change(unlock_bridge_tx_id, BridgeStatus::Pending);
        let success = bridge.handle_bridge_failure(unlock_bridge_tx_id, 'bitcoin_send_failed');
        
        assert(success, 'Failure handling should succeed');
        
        // Check that wrapped Bitcoin was restored
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == amount, 'Wrapped Bitcoin should be restored');
    }

    #[test]
    fn test_retry_failed_transaction() {
        let bridge = setup_real_bridge();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        // Create and fail a transaction
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        set_caller_address(contract_address_const::<AUTHORIZED_CONTRACT>());
        bridge.handle_bridge_failure(bridge_tx_id, 'network_error');
        
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Failed, 'Should be failed');
        
        // Retry the transaction
        set_caller_address(contract_address_const::<OWNER>());
        let success = bridge.retry_bridge_transaction(bridge_tx_id);
        
        assert(success, 'Retry should succeed');
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Pending, 'Should be pending again');
    }

    #[test]
    #[should_panic(expected: ('Transaction not failed',))]
    fn test_retry_non_failed_transaction() {
        let bridge = setup_real_bridge();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        // Try to retry a pending transaction (should fail)
        set_caller_address(contract_address_const::<OWNER>());
        bridge.retry_bridge_transaction(bridge_tx_id);
    }

    #[test]
    fn test_transaction_timeout_cancellation() {
        let bridge = setup_real_bridge();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        // Set initial timestamp
        set_block_timestamp(1000);
        
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        // Fast forward time by more than 1 hour (3600 seconds)
        set_block_timestamp(1000 + 3700);
        
        // Cancel timed out transaction
        let success = bridge.cancel_timed_out_transaction(bridge_tx_id);
        
        assert(success, 'Timeout cancellation should succeed');
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Cancelled, 'Should be cancelled');
        
        // Check that funds were refunded
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == 0, 'Wrapped Bitcoin should be refunded');
    }

    #[test]
    #[should_panic(expected: ('Transaction not timed out',))]
    fn test_cancel_non_timed_out_transaction() {
        let bridge = setup_real_bridge();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        set_block_timestamp(1000);
        
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        // Try to cancel before timeout (should fail)
        set_block_timestamp(1000 + 1800); // Only 30 minutes
        bridge.cancel_timed_out_transaction(bridge_tx_id);
    }

    #[test]
    fn test_confirmation_requirements_by_amount() {
        let bridge = setup_real_bridge();
        
        // Test small amount (< 0.1 BTC) - requires 1 confirmation
        let small_amount = 5000000; // 0.05 BTC
        let recipient = contract_address_const::<RECIPIENT>();
        
        set_caller_address(contract_address_const::<USER>());
        let small_tx_id = bridge.lock_bitcoin(small_amount, recipient, 'small_tx');
        
        set_caller_address(contract_address_const::<AUTHORIZED_CONTRACT>());
        let small_success = bridge.process_bitcoin_to_wbtc_conversion(small_tx_id, 1);
        assert(small_success, 'Small amount should confirm with 1 confirmation');
        
        // Test medium amount (0.1-1 BTC) - requires 3 confirmations
        let medium_amount = 50000000; // 0.5 BTC
        set_caller_address(contract_address_const::<USER>());
        let medium_tx_id = bridge.lock_bitcoin(medium_amount, recipient, 'medium_tx');
        
        set_caller_address(contract_address_const::<AUTHORIZED_CONTRACT>());
        let medium_fail = bridge.process_bitcoin_to_wbtc_conversion(medium_tx_id, 2); // Only 2 confirmations
        assert(!medium_fail, 'Medium amount should fail with 2 confirmations');
        
        let medium_success = bridge.process_bitcoin_to_wbtc_conversion(medium_tx_id, 3);
        assert(medium_success, 'Medium amount should confirm with 3 confirmations');
        
        // Test large amount (>= 1 BTC) - requires 6 confirmations
        let large_amount = 150000000; // 1.5 BTC
        set_caller_address(contract_address_const::<USER>());
        let large_tx_id = bridge.lock_bitcoin(large_amount, recipient, 'large_tx');
        
        set_caller_address(contract_address_const::<AUTHORIZED_CONTRACT>());
        let large_fail = bridge.process_bitcoin_to_wbtc_conversion(large_tx_id, 5); // Only 5 confirmations
        assert(!large_fail, 'Large amount should fail with 5 confirmations');
        
        let large_success = bridge.process_bitcoin_to_wbtc_conversion(large_tx_id, 6);
        assert(large_success, 'Large amount should confirm with 6 confirmations');
    }

    #[test]
    fn test_integration_with_mock_bridge() {
        let (bridge, mock_helpers) = setup_mock_bridge();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        // Test successful flow with mock
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        // Mock confirms immediately
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Confirmed, 'Mock should confirm immediately');
        assert(mock_helpers.get_lock_call_count() == 1, 'Should track lock call');
        
        // Test failure simulation
        mock_helpers.set_should_fail_lock(true);
        
        let result = std::panic::catch_unwind(|| {
            bridge.lock_bitcoin(amount, recipient, 'another_tx');
        });
        assert(result.is_err(), 'Mock should simulate failure');
        
        // Reset and test unlock
        mock_helpers.set_should_fail_lock(false);
        set_caller_address(recipient);
        let unlock_success = bridge.unlock_bitcoin(1, amount / 2, 'bitcoin_addr');
        
        assert(unlock_success, 'Mock unlock should succeed');
        assert(mock_helpers.get_unlock_call_count() == 1, 'Should track unlock call');
    }

    #[test]
    fn test_error_handling_edge_cases() {
        let bridge = setup_real_bridge();
        
        // Test handling failure on non-existent transaction
        set_caller_address(contract_address_const::<AUTHORIZED_CONTRACT>());
        let result = std::panic::catch_unwind(|| {
            bridge.handle_bridge_failure(999, 'non_existent');
        });
        assert(result.is_err(), 'Should fail for non-existent transaction');
        
        // Test processing conversion on non-existent transaction
        let result2 = std::panic::catch_unwind(|| {
            bridge.process_bitcoin_to_wbtc_conversion(999, 3);
        });
        assert(result2.is_err(), 'Should fail for non-existent transaction');
    }

    #[test]
    fn test_authorization_requirements() {
        let bridge = setup_real_bridge();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        // Try to process conversion without authorization (should fail)
        set_caller_address(contract_address_const::<USER>());
        let result = std::panic::catch_unwind(|| {
            bridge.process_bitcoin_to_wbtc_conversion(bridge_tx_id, 3);
        });
        assert(result.is_err(), 'Should require authorization');
        
        // Try to handle failure without authorization (should fail)
        let result2 = std::panic::catch_unwind(|| {
            bridge.handle_bridge_failure(bridge_tx_id, 'test_failure');
        });
        assert(result2.is_err(), 'Should require authorization');
    }
}