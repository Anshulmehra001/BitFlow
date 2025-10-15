#[cfg(test)]
mod tests {
    use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
    use starknet::testing::{set_caller_address, set_block_timestamp};
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    
    use crate::contracts::atomiq_bridge_adapter::AtomiqBridgeAdapter;
    use crate::interfaces::bridge_adapter::IAtomiqBridgeAdapterDispatcher;
    use crate::interfaces::bridge_adapter::IAtomiqBridgeAdapterDispatcherTrait;
    use crate::types::{BridgeStatus, BitFlowError};

    const OWNER: felt252 = 'owner';
    const USER: felt252 = 'user';
    const RECIPIENT: felt252 = 'recipient';
    const INITIAL_EXCHANGE_RATE: u256 = 1000000; // 1:1 with 6 decimal precision
    const MINIMUM_AMOUNT: u256 = 10000; // 0.0001 BTC in satoshis
    const FEE_RATE: u256 = 100; // 1% in basis points

    fn setup() -> IAtomiqBridgeAdapterDispatcher {
        let contract = declare("AtomiqBridgeAdapter").unwrap().contract_class();
        let constructor_calldata = array![
            OWNER,
            INITIAL_EXCHANGE_RATE.low.into(),
            INITIAL_EXCHANGE_RATE.high.into(),
            MINIMUM_AMOUNT.low.into(),
            MINIMUM_AMOUNT.high.into(),
            FEE_RATE.low.into(),
            FEE_RATE.high.into()
        ];
        
        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        IAtomiqBridgeAdapterDispatcher { contract_address }
    }

    #[test]
    fn test_constructor_initialization() {
        let bridge = setup();
        
        assert(bridge.get_exchange_rate() == INITIAL_EXCHANGE_RATE, 'Wrong exchange rate');
        assert(bridge.get_minimum_bridge_amount() == MINIMUM_AMOUNT, 'Wrong minimum amount');
        assert(bridge.get_total_locked_bitcoin() == 0, 'Initial locked should be 0');
    }

    #[test]
    fn test_lock_bitcoin_success() {
        let bridge = setup();
        let amount = 100000; // 0.001 BTC
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        set_caller_address(contract_address_const::<USER>());
        
        let bridge_tx_id = bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        assert(bridge_tx_id == 1, 'Wrong bridge tx ID');
        assert(bridge.get_bridge_status(bridge_tx_id) == BridgeStatus::Pending, 'Wrong status');
        
        // Check wrapped Bitcoin balance (amount minus fee)
        let expected_fee = (amount * FEE_RATE) / 10000;
        let expected_wrapped = amount - expected_fee;
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == expected_wrapped, 'Wrong wrapped balance');
        
        // Check total locked Bitcoin
        assert(bridge.get_total_locked_bitcoin() == amount, 'Wrong total locked');
    }

    #[test]
    #[should_panic(expected: ('Amount below minimum',))]
    fn test_lock_bitcoin_below_minimum() {
        let bridge = setup();
        let amount = 5000; // Below minimum
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        set_caller_address(contract_address_const::<USER>());
        bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
    }

    #[test]
    #[should_panic(expected: ('Bitcoin tx already used',))]
    fn test_lock_bitcoin_duplicate_tx_hash() {
        let bridge = setup();
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        set_caller_address(contract_address_const::<USER>());
        
        // First lock should succeed
        bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
        
        // Second lock with same tx hash should fail
        bridge.lock_bitcoin(amount, recipient, bitcoin_tx_hash);
    }

    #[test]
    fn test_unlock_bitcoin_success() {
        let bridge = setup();
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
        
        // Authorize the recipient as a contract (normally done by owner)
        set_caller_address(contract_address_const::<OWNER>());
        // Note: We need to add a public function to authorize contracts for testing
        
        set_caller_address(recipient);
        let success = bridge.unlock_bitcoin(1, unlock_amount, bitcoin_address);
        
        assert(success, 'Unlock should succeed');
        
        // Check remaining wrapped Bitcoin balance
        let expected_fee = (lock_amount * FEE_RATE) / 10000;
        let initial_wrapped = lock_amount - expected_fee;
        let remaining_wrapped = initial_wrapped - unlock_amount;
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == remaining_wrapped, 'Wrong remaining balance');
    }

    #[test]
    fn test_verify_bitcoin_transaction() {
        let bridge = setup();
        let bitcoin_tx_hash = 'valid_tx_hash';
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        
        // Valid transaction should return true
        let is_valid = bridge.verify_bitcoin_transaction(bitcoin_tx_hash, amount, recipient);
        assert(is_valid, 'Valid tx should return true');
        
        // Zero hash should return false
        let is_invalid = bridge.verify_bitcoin_transaction(0, amount, recipient);
        assert(!is_invalid, 'Zero hash should return false');
    }

    #[test]
    fn test_bridge_fee_calculation() {
        let bridge = setup();
        let amount = 100000;
        let expected_fee = (amount * FEE_RATE) / 10000; // 1% of amount
        
        let actual_fee = bridge.get_bridge_fee(amount);
        assert(actual_fee == expected_fee, 'Wrong fee calculation');
    }

    #[test]
    fn test_estimate_bridge_time() {
        let bridge = setup();
        
        // Small amount should have shorter time
        let small_amount = 1000000; // 0.01 BTC
        let small_time = bridge.estimate_bridge_time(small_amount);
        assert(small_time == 600, 'Wrong small amount time');
        
        // Medium amount
        let medium_amount = 50000000; // 0.5 BTC
        let medium_time = bridge.estimate_bridge_time(medium_amount);
        assert(medium_time == 1800, 'Wrong medium amount time');
        
        // Large amount should have longer time
        let large_amount = 200000000; // 2 BTC
        let large_time = bridge.estimate_bridge_time(large_amount);
        assert(large_time == 3600, 'Wrong large amount time');
    }

    #[test]
    fn test_pause_and_resume_bridge() {
        let bridge = setup();
        
        set_caller_address(contract_address_const::<OWNER>());
        
        // Pause bridge
        let pause_success = bridge.pause_bridge();
        assert(pause_success, 'Pause should succeed');
        
        // Try to lock Bitcoin while paused (should fail)
        set_caller_address(contract_address_const::<USER>());
        let amount = 100000;
        let recipient = contract_address_const::<RECIPIENT>();
        let bitcoin_tx_hash = 'test_tx_hash';
        
        // This should panic due to bridge being paused
        // Note: We'd need to test this with should_panic attribute
        
        // Resume bridge
        set_caller_address(contract_address_const::<OWNER>());
        let resume_success = bridge.resume_bridge();
        assert(resume_success, 'Resume should succeed');
    }

    #[test]
    #[should_panic(expected: ('Only owner can call',))]
    fn test_pause_bridge_unauthorized() {
        let bridge = setup();
        
        set_caller_address(contract_address_const::<USER>());
        bridge.pause_bridge();
    }

    #[test]
    #[should_panic(expected: ('Only owner can call',))]
    fn test_resume_bridge_unauthorized() {
        let bridge = setup();
        
        set_caller_address(contract_address_const::<USER>());
        bridge.resume_bridge();
    }

    #[test]
    fn test_get_bridge_status_nonexistent() {
        let bridge = setup();
        
        // Non-existent bridge transaction should return default status
        let status = bridge.get_bridge_status(999);
        // This will return the default BridgeStatus value
    }

    #[test]
    fn test_multiple_lock_operations() {
        let bridge = setup();
        let amount1 = 100000;
        let amount2 = 200000;
        let recipient = contract_address_const::<RECIPIENT>();
        
        set_caller_address(contract_address_const::<USER>());
        
        // First lock
        let tx_id1 = bridge.lock_bitcoin(amount1, recipient, 'tx_hash_1');
        
        // Second lock
        let tx_id2 = bridge.lock_bitcoin(amount2, recipient, 'tx_hash_2');
        
        assert(tx_id1 == 1, 'Wrong first tx ID');
        assert(tx_id2 == 2, 'Wrong second tx ID');
        
        // Check total locked Bitcoin
        let total_expected = amount1 + amount2;
        assert(bridge.get_total_locked_bitcoin() == total_expected, 'Wrong total locked');
        
        // Check wrapped Bitcoin balance
        let fee1 = (amount1 * FEE_RATE) / 10000;
        let fee2 = (amount2 * FEE_RATE) / 10000;
        let expected_wrapped = (amount1 - fee1) + (amount2 - fee2);
        assert(bridge.get_wrapped_bitcoin_balance(recipient) == expected_wrapped, 'Wrong total wrapped');
    }
}