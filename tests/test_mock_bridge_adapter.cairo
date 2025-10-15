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
    fn test_mock_constructor_defaults() {
        let (bridge, _) = setup();
        
        assert(bridge.get_exchange_rate() == 1000000, 'Wrong default exchange rate');
        assert(bridge.get_minimum_bridge_amount() == 10000, 'Wrong default minimum');
        assert(bridge.get_total_locked_bitcoin() == 0, 'Initial locked should be 0');
    }

    #[test]
    fn test_mock_lock_bitcoin_success() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        set_caller_address(contract_address_const::<USER>());
        
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        assert(bridge_tx_id == 1, 'Wrong bridge tx ID');
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Confirmed, 'Mock should confirm immediately');
        
        // Check mock tracking
        assert(mock_helpers.get_last_lock_amount() == amount, 'Wrong tracked lock amount');
        assert(mock_helpers.get_lock_call_count() == 1, 'Wrong lock call count');
        
        // Check wrapped Bitcoin balance (amount minus 1% fee)
        let expected_wrapped = amount - (amount * 100) / 10000; // 1% fee
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == expected_wrapped, 'Wrong wrapped balance');
    }

    #[test]
    fn test_mock_lock_failure_simulation() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        // Configure mock to fail
        mock_helpers.set_should_fail_lock(true);
        
        set_caller_address(contract_address_const::<USER>());
        
        // This should panic due to mock failure
        let result = std::panic::catch_unwind(|| {
            bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        });
        
        assert(result.is_err(), 'Mock should have failed');
    }

    #[test]
    fn test_mock_unlock_bitcoin_success() {
        let (bridge, mock_helpers) = setup();
        let lock_amount = 100000;
        let unlock_amount = 50000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        let bitcoin_address = 'bitcoin_addr';
        
        // First lock some Bitcoin
        set_caller_address(contract_address_const::<USER>());
        bridge.lock_bitcoin(lock_amount, recipient, bitcoin_tx_hash);
        
        // Now unlock from recipient's perspective
        set_caller_address(recipient);
        let success = bridge.unlock_bitcoin(1, unlock_amount, bitcoin_address);
        
        assert(success, 'Mock unlock should succeed');
        
        // Check mock tracking
        assert(mock_helpers.get_last_unlock_amount() == unlock_amount, 'Wrong tracked unlock amount');
        assert(mock_helpers.get_unlock_call_count() == 1, 'Wrong unlock call count');
        
        // Check remaining balance
        let expected_fee = (lock_amount * 100) / 10000;
        let initial_wrapped = lock_amount - expected_fee;
        let remaining = initial_wrapped - unlock_amount;
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == remaining, 'Wrong remaining balance');
    }

    #[test]
    fn test_mock_unlock_failure_simulation() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let bitcoin_address = 'bitcoin_addr';
        
        // Configure mock to fail unlocks
        mock_helpers.set_should_fail_unlock(true);
        
        set_caller_address(contract_address_const::<USER>());
        let success = bridge.unlock_bitcoin(1, amount, bitcoin_address);
        
        assert(!success, 'Mock unlock should fail');
    }

    #[test]
    fn test_mock_verification_success() {
        let (bridge, _) = setup();
        let bitcoin_tx_hash = 'valid_tx_hash';
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        
        let is_valid = bridge.verify_bitcoin_transaction(bitcoin_tx_hash, amount, recipient);
        assert(is_valid, 'Mock verification should succeed');
    }

    #[test]
    fn test_mock_verification_failure_simulation() {
        let (bridge, mock_helpers) = setup();
        let bitcoin_tx_hash = 'valid_tx_hash';
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        
        // Configure mock to fail verification
        mock_helpers.set_should_fail_verification(true);
        
        let is_valid = bridge.verify_bitcoin_transaction(bitcoin_tx_hash, amount, recipient);
        assert(!is_valid, 'Mock verification should fail');
    }

    #[test]
    fn test_mock_configuration_updates() {
        let (bridge, mock_helpers) = setup();
        
        // Test exchange rate update
        let new_rate = 2000000;
        mock_helpers.set_mock_exchange_rate(new_rate);
        assert(bridge.get_exchange_rate() == new_rate, 'Exchange rate not updated');
        
        // Test minimum amount update
        let new_minimum = 20000;
        mock_helpers.set_mock_minimum_amount(new_minimum);
        assert(bridge.get_minimum_bridge_amount() == new_minimum, 'Minimum amount not updated');
        
        // Test fee rate update
        let new_fee_rate = 200; // 2%
        mock_helpers.set_mock_fee_rate(new_fee_rate);
        let test_amount = 100000;
        let expected_fee = (test_amount * new_fee_rate) / 10000;
        assert(bridge.get_bridge_fee(test_amount) == expected_fee, 'Fee rate not updated');
        
        // Test bridge time update
        let new_time = 1200; // 20 minutes
        mock_helpers.set_mock_bridge_time(new_time);
        assert(bridge.estimate_bridge_time(100000) == new_time, 'Bridge time not updated');
    }

    #[test]
    fn test_mock_status_simulation() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        set_caller_address(contract_address_const::<USER>());
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        // Initially should be confirmed (mock default)
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Confirmed, 'Initial status wrong');
        
        // Simulate status change to pending
        mock_helpers.simulate_status_change(bridge_tx_id, BridgeStatus::Pending);
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Pending, 'Status not changed');
        
        // Simulate status change to failed
        mock_helpers.simulate_status_change(bridge_tx_id, BridgeStatus::Failed);
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Failed, 'Status not changed to failed');
    }

    #[test]
    fn test_mock_balance_manipulation() {
        let (bridge, mock_helpers) = setup();
        let recipient = contract_address_const::<RECIPIENT>();
        let amount = 500000;
        
        // Add balance directly for testing
        mock_helpers.add_wrapped_bitcoin_balance(recipient, amount);
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == amount, 'Balance not added');
        
        // Add more balance
        mock_helpers.add_wrapped_bitcoin_balance(recipient, amount);
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == amount * 2, 'Balance not accumulated');
    }

    #[test]
    fn test_mock_state_reset() {
        let (bridge, mock_helpers) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        set_caller_address(contract_address_const::<USER>());
        
        // Perform some operations
        bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        bridge.unlock_bitcoin(1, amount / 2, 'bitcoin_addr');
        
        // Check that counters are set
        assert(mock_helpers.get_lock_call_count() == 1, 'Lock count should be 1');
        assert(mock_helpers.get_unlock_call_count() == 1, 'Unlock count should be 1');
        
        // Reset state
        mock_helpers.reset_mock_state();
        
        // Check that counters are reset
        assert(mock_helpers.get_lock_call_count() == 0, 'Lock count should be reset');
        assert(mock_helpers.get_unlock_call_count() == 0, 'Unlock count should be reset');
        assert(mock_helpers.get_last_lock_amount() == 0, 'Last lock amount should be reset');
        assert(mock_helpers.get_last_unlock_amount() == 0, 'Last unlock amount should be reset');
    }

    #[test]
    fn test_mock_pause_resume() {
        let (bridge, _) = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        // Pause bridge
        let pause_success = bridge.pause_bridge();
        assert(pause_success, 'Pause should succeed');
        
        // Try to lock while paused (should fail)
        set_caller_address(contract_address_const::<USER>());
        let result = std::panic::catch_unwind(|| {
            bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        });
        assert(result.is_err(), 'Should fail when paused');
        
        // Resume bridge
        let resume_success = bridge.resume_bridge();
        assert(resume_success, 'Resume should succeed');
        
        // Now lock should work
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        assert(bridge_tx_id == 1, 'Lock should work after resume');
    }

    #[test]
    fn test_mock_multiple_operations_tracking() {
        let (bridge, mock_helpers) = setup();
        let recipient = contract_address_const::<RECIPIENT>();
        
        set_caller_address(contract_address_const::<USER>());
        
        // Perform multiple lock operations
        bridge.lock_bitcoin(100000, recipient, 'tx1');
        bridge.lock_bitcoin(200000, recipient, 'tx2');
        bridge.lock_bitcoin(300000, recipient, 'tx3');
        
        assert(mock_helpers.get_lock_call_count() == 3, 'Should track 3 lock calls');
        assert(mock_helpers.get_last_lock_amount() == 300000, 'Should track last lock amount');
        
        // Perform multiple unlock operations
        set_caller_address(recipient);
        bridge.unlock_bitcoin(1, 50000, 'addr1');
        bridge.unlock_bitcoin(2, 75000, 'addr2');
        
        assert(mock_helpers.get_unlock_call_count() == 2, 'Should track 2 unlock calls');
        assert(mock_helpers.get_last_unlock_amount() == 75000, 'Should track last unlock amount');
    }
}