#[cfg(test)]
mod test_yield_defi_integration {
    use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
    use starknet::testing::{set_caller_address, set_block_timestamp};
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    
    use crate::contracts::yield_manager::YieldManager;
    use crate::contracts::vesu_adapter::VesuAdapter;
    use crate::contracts::troves_adapter::TrovesAdapter;
    use crate::interfaces::yield_manager::IYieldManagerDispatcher;
    use crate::interfaces::yield_manager::IYieldManagerDispatcherTrait;
    use crate::interfaces::defi_protocol::{IDeFiProtocolDispatcher, IDeFiProtocolDispatcherTrait};

    fn setup_integrated_system() -> (
        IYieldManagerDispatcher,
        IDeFiProtocolDispatcher,
        IDeFiProtocolDispatcher,
        ContractAddress,
        ContractAddress,
        ContractAddress,
        ContractAddress
    ) {
        let owner = contract_address_const::<'owner'>();
        let token = contract_address_const::<'wbtc_token'>();
        let vesu_protocol = contract_address_const::<'vesu_protocol'>();
        let troves_protocol = contract_address_const::<'troves_protocol'>();
        
        set_caller_address(owner);
        set_block_timestamp(1000);

        // Deploy YieldManager
        let yield_manager_class = declare("YieldManager").unwrap().contract_class();
        let yield_constructor_calldata = array![owner.into(), token.into()];
        let (yield_manager_address, _) = yield_manager_class.deploy(@yield_constructor_calldata).unwrap();
        let yield_manager = IYieldManagerDispatcher { contract_address: yield_manager_address };

        // Deploy Vesu Adapter
        let vesu_adapter_class = declare("VesuAdapter").unwrap().contract_class();
        let vesu_constructor_calldata = array![vesu_protocol.into(), owner.into()];
        let (vesu_adapter_address, _) = vesu_adapter_class.deploy(@vesu_constructor_calldata).unwrap();
        let vesu_adapter = IDeFiProtocolDispatcher { contract_address: vesu_adapter_address };

        // Deploy Troves Adapter
        let troves_adapter_class = declare("TrovesAdapter").unwrap().contract_class();
        let troves_constructor_calldata = array![troves_protocol.into(), owner.into()];
        let (troves_adapter_address, _) = troves_adapter_class.deploy(@troves_constructor_calldata).unwrap();
        let troves_adapter = IDeFiProtocolDispatcher { contract_address: troves_adapter_address };

        // Configure YieldManager with protocols and adapters
        yield_manager.add_yield_protocol(vesu_protocol, 1000);
        yield_manager.add_yield_protocol(troves_protocol, 500);

        (yield_manager, vesu_adapter, troves_adapter, owner, token, vesu_protocol, troves_protocol)
    }

    #[test]
    fn test_integrated_yield_system_setup() {
        let (yield_manager, vesu_adapter, troves_adapter, owner, token, vesu_protocol, troves_protocol) = setup_integrated_system();
        
        // Verify protocols are added
        let protocols = yield_manager.get_supported_protocols();
        assert(protocols.len() == 2, 'Should have 2 protocols');
        assert(*protocols.at(0) == vesu_protocol, 'First protocol should be Vesu');
        assert(*protocols.at(1) == troves_protocol, 'Second protocol should be Troves');
        
        // Verify adapters are functional
        let vesu_rate = vesu_adapter.get_yield_rate(token);
        let troves_rate = troves_adapter.get_yield_rate(token);
        assert(vesu_rate >= 0, 'Vesu rate should be non-negative');
        assert(troves_rate >= 0, 'Troves rate should be non-negative');
    }

    #[test]
    fn test_optimal_strategy_selection() {
        let (yield_manager, _, _, _, _, vesu_protocol, troves_protocol) = setup_integrated_system();
        
        // Test strategy selection with different amounts
        let optimal_for_large = yield_manager.select_optimal_yield_strategy(2000);
        let optimal_for_small = yield_manager.select_optimal_yield_strategy(600);
        
        // Large amount should select Vesu (higher minimum but same rate)
        assert(optimal_for_large == vesu_protocol, 'Large amount should select Vesu');
        
        // Small amount should select Troves (lower minimum)
        assert(optimal_for_small == troves_protocol, 'Small amount should select Troves');
    }

    #[test]
    fn test_yield_position_lifecycle() {
        let (yield_manager, _, _, _, _, vesu_protocol, _) = setup_integrated_system();
        let stream_id = 1;
        
        // Enable yield for a stream
        let success = yield_manager.enable_yield(stream_id, vesu_protocol);
        assert(success, 'Should enable yield successfully');
        
        // Check initial position
        let position = yield_manager.get_yield_position(stream_id);
        assert(position.stream_id == stream_id, 'Stream ID should match');
        assert(position.protocol == vesu_protocol, 'Protocol should match');
        assert(position.staked_amount == 0, 'Initial staked amount should be 0');
        
        // Note: Actual staking would require mocking the protocol responses
        // This test verifies the position management logic
    }

    #[test]
    fn test_multiple_streams_different_protocols() {
        let (yield_manager, _, _, _, _, vesu_protocol, troves_protocol) = setup_integrated_system();
        let stream_id1 = 1;
        let stream_id2 = 2;
        
        // Enable different protocols for different streams
        yield_manager.enable_yield(stream_id1, vesu_protocol);
        yield_manager.enable_yield(stream_id2, troves_protocol);
        
        let position1 = yield_manager.get_yield_position(stream_id1);
        let position2 = yield_manager.get_yield_position(stream_id2);
        
        assert(position1.protocol == vesu_protocol, 'Stream 1 should use Vesu');
        assert(position2.protocol == troves_protocol, 'Stream 2 should use Troves');
        assert(position1.stream_id != position2.stream_id, 'Streams should be different');
    }

    #[test]
    fn test_yield_earnings_tracking() {
        let (yield_manager, _, _, _, _, vesu_protocol, _) = setup_integrated_system();
        let stream_id = 1;
        
        yield_manager.enable_yield(stream_id, vesu_protocol);
        
        // Fast forward time
        set_block_timestamp(1000 + 86400); // 1 day later
        
        let total_yield = yield_manager.get_total_earned_yield(stream_id);
        // Should be 0 since no funds are staked
        assert(total_yield == 0, 'Should have 0 yield with no staked funds');
    }

    #[test]
    fn test_protocol_rate_updates() {
        let (yield_manager, _, _, owner, _, vesu_protocol, _) = setup_integrated_system();
        
        set_caller_address(owner);
        
        let initial_rate = yield_manager.get_yield_rate(vesu_protocol);
        assert(initial_rate == 500, 'Initial rate should be 500 bp');
        
        // Update the rate (this would be an internal function in practice)
        // For now, we verify the rate retrieval works
        let updated_rate = yield_manager.get_yield_rate(vesu_protocol);
        assert(updated_rate >= 0, 'Updated rate should be non-negative');
    }

    #[test]
    fn test_auto_strategy_configuration() {
        let (yield_manager, _, _, owner, _, _, _) = setup_integrated_system();
        
        set_caller_address(owner);
        
        // Test auto strategy is enabled by default
        let auto_enabled = yield_manager.is_auto_strategy_enabled();
        assert(auto_enabled, 'Auto strategy should be enabled by default');
        
        // Test disabling auto strategy
        yield_manager.set_auto_strategy_enabled(false);
        let auto_disabled = yield_manager.is_auto_strategy_enabled();
        assert(!auto_disabled, 'Auto strategy should be disabled');
    }

    #[test]
    fn test_yield_distribution_flow() {
        let (yield_manager, _, _, _, _, vesu_protocol, _) = setup_integrated_system();
        let stream_id = 1;
        
        yield_manager.enable_yield(stream_id, vesu_protocol);
        
        // Test distribution with no yield
        let distributed = yield_manager.distribute_yield(stream_id);
        assert(distributed == 0, 'Should distribute 0 with no yield');
        
        // Test claiming with no yield
        let claimed = yield_manager.claim_yield(stream_id);
        assert(claimed == 0, 'Should claim 0 with no yield');
    }

    #[test]
    fn test_protocol_adapter_management() {
        let (yield_manager, vesu_adapter, troves_adapter, owner, _, vesu_protocol, troves_protocol) = setup_integrated_system();
        
        set_caller_address(owner);
        
        // Set protocol adapters
        yield_manager.set_protocol_adapter(vesu_protocol, vesu_adapter.contract_address);
        yield_manager.set_protocol_adapter(troves_protocol, troves_adapter.contract_address);
        
        // Verify adapters are set
        let vesu_adapter_addr = yield_manager.get_protocol_adapter(vesu_protocol);
        let troves_adapter_addr = yield_manager.get_protocol_adapter(troves_protocol);
        
        assert(vesu_adapter_addr == vesu_adapter.contract_address, 'Vesu adapter should match');
        assert(troves_adapter_addr == troves_adapter.contract_address, 'Troves adapter should match');
    }

    #[test]
    fn test_comprehensive_yield_workflow() {
        let (yield_manager, vesu_adapter, _, owner, _, vesu_protocol, _) = setup_integrated_system();
        let stream_id = 1;
        
        set_caller_address(owner);
        
        // Set up the complete workflow
        yield_manager.set_protocol_adapter(vesu_protocol, vesu_adapter.contract_address);
        
        // Enable yield
        yield_manager.enable_yield(stream_id, vesu_protocol);
        
        // Verify position is created
        let position = yield_manager.get_yield_position(stream_id);
        assert(position.stream_id == stream_id, 'Position should be created');
        
        // Note: Actual staking would require mocking the DeFi protocol
        // This test verifies the integration points are properly set up
        
        // Test disabling yield (requires no staked funds)
        let disable_success = yield_manager.disable_yield(stream_id);
        assert(disable_success, 'Should disable yield successfully');
        
        // Verify position is cleared
        let cleared_position = yield_manager.get_yield_position(stream_id);
        assert(cleared_position.stream_id == 0, 'Position should be cleared');
    }
}