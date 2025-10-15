#[cfg(test)]
mod test_yield_manager {
    use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
    use starknet::testing::{set_caller_address, set_block_timestamp};
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    
    use crate::contracts::yield_manager::YieldManager;
    use crate::interfaces::yield_manager::IYieldManagerDispatcher;
    use crate::interfaces::yield_manager::IYieldManagerDispatcherTrait;
    use crate::types::YieldPosition;

    fn setup() -> (IYieldManagerDispatcher, ContractAddress, ContractAddress) {
        let owner = contract_address_const::<'owner'>();
        let protocol1 = contract_address_const::<'protocol1'>();
        
        set_caller_address(owner);
        set_block_timestamp(1000);

        let contract_class = declare("YieldManager").unwrap().contract_class();
        let constructor_calldata = array![owner.into()];
        let (contract_address, _) = contract_class.deploy(@constructor_calldata).unwrap();
        
        let yield_manager = IYieldManagerDispatcher { contract_address };
        
        // Add a test protocol
        yield_manager.add_yield_protocol(protocol1, 1000); // Min stake: 1000
        
        (yield_manager, owner, protocol1)
    }

    #[test]
    fn test_constructor() {
        let (yield_manager, owner, protocol1) = setup();
        
        // Test that protocol was added
        let protocols = yield_manager.get_supported_protocols();
        assert(protocols.len() == 1, 'Should have 1 protocol');
        assert(*protocols.at(0) == protocol1, 'Protocol should match');
    }

    #[test]
    fn test_add_yield_protocol() {
        let (yield_manager, owner, _) = setup();
        let protocol2 = contract_address_const::<'protocol2'>();
        
        set_caller_address(owner);
        let success = yield_manager.add_yield_protocol(protocol2, 2000);
        assert(success, 'Should add protocol successfully');
        
        let protocols = yield_manager.get_supported_protocols();
        assert(protocols.len() == 2, 'Should have 2 protocols');
        
        let rate = yield_manager.get_yield_rate(protocol2);
        assert(rate == 500, 'Default rate should be 500 bp');
    }

    #[test]
    #[should_panic(expected: ('Only owner allowed',))]
    fn test_add_yield_protocol_unauthorized() {
        let (yield_manager, _, _) = setup();
        let protocol2 = contract_address_const::<'protocol2'>();
        let unauthorized = contract_address_const::<'unauthorized'>();
        
        set_caller_address(unauthorized);
        yield_manager.add_yield_protocol(protocol2, 2000);
    }

    #[test]
    fn test_enable_yield() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        
        let success = yield_manager.enable_yield(stream_id, protocol1);
        assert(success, 'Should enable yield successfully');
        
        let position = yield_manager.get_yield_position(stream_id);
        assert(position.stream_id == stream_id, 'Stream ID should match');
        assert(position.protocol == protocol1, 'Protocol should match');
        assert(position.staked_amount == 0, 'Initial staked amount should be 0');
        assert(position.earned_yield == 0, 'Initial earned yield should be 0');
    }

    #[test]
    #[should_panic(expected: ('Protocol not supported',))]
    fn test_enable_yield_unsupported_protocol() {
        let (yield_manager, _, _) = setup();
        let stream_id = 1;
        let unsupported_protocol = contract_address_const::<'unsupported'>();
        
        yield_manager.enable_yield(stream_id, unsupported_protocol);
    }

    #[test]
    fn test_stake_idle_funds() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        let stake_amount = 5000;
        
        // First enable yield
        yield_manager.enable_yield(stream_id, protocol1);
        
        // Then stake funds
        let success = yield_manager.stake_idle_funds(stream_id, stake_amount, protocol1);
        assert(success, 'Should stake funds successfully');
        
        let position = yield_manager.get_yield_position(stream_id);
        assert(position.staked_amount == stake_amount, 'Staked amount should match');
        assert(position.protocol == protocol1, 'Protocol should match');
    }

    #[test]
    #[should_panic(expected: ('Amount below minimum stake',))]
    fn test_stake_idle_funds_below_minimum() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        let stake_amount = 500; // Below minimum of 1000
        
        yield_manager.enable_yield(stream_id, protocol1);
        yield_manager.stake_idle_funds(stream_id, stake_amount, protocol1);
    }

    #[test]
    fn test_stake_multiple_times() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        
        yield_manager.enable_yield(stream_id, protocol1);
        
        // First stake
        yield_manager.stake_idle_funds(stream_id, 2000, protocol1);
        let position1 = yield_manager.get_yield_position(stream_id);
        assert(position1.staked_amount == 2000, 'First stake should be 2000');
        
        // Second stake
        yield_manager.stake_idle_funds(stream_id, 3000, protocol1);
        let position2 = yield_manager.get_yield_position(stream_id);
        assert(position2.staked_amount == 5000, 'Total stake should be 5000');
    }

    #[test]
    fn test_unstake_funds() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        
        yield_manager.enable_yield(stream_id, protocol1);
        yield_manager.stake_idle_funds(stream_id, 5000, protocol1);
        
        let success = yield_manager.unstake_funds(stream_id, 2000);
        assert(success, 'Should unstake funds successfully');
        
        let position = yield_manager.get_yield_position(stream_id);
        assert(position.staked_amount == 3000, 'Remaining stake should be 3000');
    }

    #[test]
    #[should_panic(expected: ('Insufficient staked amount',))]
    fn test_unstake_funds_insufficient() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        
        yield_manager.enable_yield(stream_id, protocol1);
        yield_manager.stake_idle_funds(stream_id, 2000, protocol1);
        
        // Try to unstake more than staked
        yield_manager.unstake_funds(stream_id, 3000);
    }

    #[test]
    #[should_panic(expected: ('No yield position found',))]
    fn test_unstake_funds_no_position() {
        let (yield_manager, _, _) = setup();
        let stream_id = 1;
        
        yield_manager.unstake_funds(stream_id, 1000);
    }

    #[test]
    fn test_yield_calculation_over_time() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        let stake_amount = 10000;
        
        // Enable yield and stake funds
        yield_manager.enable_yield(stream_id, protocol1);
        yield_manager.stake_idle_funds(stream_id, stake_amount, protocol1);
        
        // Fast forward time by 1 year (31536000 seconds)
        set_block_timestamp(1000 + 31536000);
        
        let total_yield = yield_manager.get_total_earned_yield(stream_id);
        
        // With 5% APY (500 basis points) on 10000, should earn ~500 after 1 year
        // Allow for some rounding differences
        assert(total_yield >= 490 && total_yield <= 510, 'Yield should be ~500');
    }

    #[test]
    fn test_distribute_yield() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        
        yield_manager.enable_yield(stream_id, protocol1);
        yield_manager.stake_idle_funds(stream_id, 10000, protocol1);
        
        // Fast forward time
        set_block_timestamp(1000 + 3153600); // ~10% of a year
        
        let distributed_yield = yield_manager.distribute_yield(stream_id);
        assert(distributed_yield > 0, 'Should distribute some yield');
        
        // After distribution, earned yield should be reset
        let position = yield_manager.get_yield_position(stream_id);
        assert(position.earned_yield == 0, 'Earned yield should be reset');
    }

    #[test]
    fn test_claim_yield() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        
        yield_manager.enable_yield(stream_id, protocol1);
        yield_manager.stake_idle_funds(stream_id, 10000, protocol1);
        
        // Fast forward time
        set_block_timestamp(1000 + 3153600);
        
        let claimed_yield = yield_manager.claim_yield(stream_id);
        assert(claimed_yield > 0, 'Should claim some yield');
        
        // Position should be updated
        let position = yield_manager.get_yield_position(stream_id);
        assert(position.earned_yield == 0, 'Earned yield should be reset after claim');
    }

    #[test]
    fn test_disable_yield() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        
        yield_manager.enable_yield(stream_id, protocol1);
        yield_manager.stake_idle_funds(stream_id, 5000, protocol1);
        
        // Must unstake all funds before disabling
        yield_manager.unstake_funds(stream_id, 5000);
        
        let success = yield_manager.disable_yield(stream_id);
        assert(success, 'Should disable yield successfully');
        
        // Position should be cleared
        let position = yield_manager.get_yield_position(stream_id);
        assert(position.stream_id == 0, 'Position should be cleared');
    }

    #[test]
    #[should_panic(expected: ('Must unstake funds first',))]
    fn test_disable_yield_with_staked_funds() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        
        yield_manager.enable_yield(stream_id, protocol1);
        yield_manager.stake_idle_funds(stream_id, 5000, protocol1);
        
        // Try to disable without unstaking
        yield_manager.disable_yield(stream_id);
    }

    #[test]
    fn test_select_optimal_yield_strategy() {
        let (yield_manager, owner, protocol1) = setup();
        let protocol2 = contract_address_const::<'protocol2'>();
        
        set_caller_address(owner);
        yield_manager.add_yield_protocol(protocol2, 500); // Lower minimum stake
        
        // Test with amount that meets both minimums
        let optimal = yield_manager.select_optimal_yield_strategy(2000);
        // Should select protocol1 as it has the same rate but was added first
        assert(optimal == protocol1, 'Should select first protocol with same rate');
        
        // Test with amount that only meets protocol2 minimum
        let optimal2 = yield_manager.select_optimal_yield_strategy(800);
        assert(optimal2 == protocol2, 'Should select protocol2 for lower amount');
    }

    #[test]
    fn test_get_supported_protocols() {
        let (yield_manager, owner, protocol1) = setup();
        let protocol2 = contract_address_const::<'protocol2'>();
        let protocol3 = contract_address_const::<'protocol3'>();
        
        set_caller_address(owner);
        yield_manager.add_yield_protocol(protocol2, 1500);
        yield_manager.add_yield_protocol(protocol3, 2000);
        
        let protocols = yield_manager.get_supported_protocols();
        assert(protocols.len() == 3, 'Should have 3 protocols');
        assert(*protocols.at(0) == protocol1, 'First protocol should match');
        assert(*protocols.at(1) == protocol2, 'Second protocol should match');
        assert(*protocols.at(2) == protocol3, 'Third protocol should match');
    }

    #[test]
    fn test_yield_rate_retrieval() {
        let (yield_manager, _, protocol1) = setup();
        
        let rate = yield_manager.get_yield_rate(protocol1);
        assert(rate == 500, 'Default rate should be 500 basis points');
    }

    #[test]
    #[should_panic(expected: ('Amount must be positive',))]
    fn test_stake_zero_amount() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        
        yield_manager.enable_yield(stream_id, protocol1);
        yield_manager.stake_idle_funds(stream_id, 0, protocol1);
    }

    #[test]
    #[should_panic(expected: ('Amount must be positive',))]
    fn test_unstake_zero_amount() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id = 1;
        
        yield_manager.enable_yield(stream_id, protocol1);
        yield_manager.stake_idle_funds(stream_id, 5000, protocol1);
        yield_manager.unstake_funds(stream_id, 0);
    }

    #[test]
    fn test_multiple_streams_yield_positions() {
        let (yield_manager, _, protocol1) = setup();
        let stream_id1 = 1;
        let stream_id2 = 2;
        
        // Set up two different streams
        yield_manager.enable_yield(stream_id1, protocol1);
        yield_manager.enable_yield(stream_id2, protocol1);
        
        yield_manager.stake_idle_funds(stream_id1, 3000, protocol1);
        yield_manager.stake_idle_funds(stream_id2, 7000, protocol1);
        
        let position1 = yield_manager.get_yield_position(stream_id1);
        let position2 = yield_manager.get_yield_position(stream_id2);
        
        assert(position1.staked_amount == 3000, 'Stream 1 stake should be 3000');
        assert(position2.staked_amount == 7000, 'Stream 2 stake should be 7000');
        assert(position1.stream_id != position2.stream_id, 'Stream IDs should differ');
    }
}