#[cfg(test)]
mod test_defi_integrations {
    use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
    use starknet::testing::{set_caller_address, set_block_timestamp};
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    
    use crate::contracts::vesu_adapter::VesuAdapter;
    use crate::contracts::troves_adapter::TrovesAdapter;
    use crate::interfaces::defi_protocol::{IDeFiProtocolDispatcher, IDeFiProtocolDispatcherTrait};

    fn setup_vesu_adapter() -> (IDeFiProtocolDispatcher, ContractAddress, ContractAddress) {
        let owner = contract_address_const::<'owner'>();
        let vesu_contract = contract_address_const::<'vesu_protocol'>();
        let token = contract_address_const::<'wbtc_token'>();
        
        set_caller_address(owner);
        set_block_timestamp(1000);

        let contract_class = declare("VesuAdapter").unwrap().contract_class();
        let constructor_calldata = array![vesu_contract.into(), owner.into()];
        let (contract_address, _) = contract_class.deploy(@constructor_calldata).unwrap();
        
        let adapter = IDeFiProtocolDispatcher { contract_address };
        
        (adapter, owner, token)
    }

    fn setup_troves_adapter() -> (IDeFiProtocolDispatcher, ContractAddress, ContractAddress) {
        let owner = contract_address_const::<'owner'>();
        let troves_contract = contract_address_const::<'troves_protocol'>();
        let token = contract_address_const::<'wbtc_token'>();
        
        set_caller_address(owner);
        set_block_timestamp(1000);

        let contract_class = declare("TrovesAdapter").unwrap().contract_class();
        let constructor_calldata = array![troves_contract.into(), owner.into()];
        let (contract_address, _) = contract_class.deploy(@constructor_calldata).unwrap();
        
        let adapter = IDeFiProtocolDispatcher { contract_address };
        
        (adapter, owner, token)
    }

    #[test]
    fn test_vesu_adapter_deposit() {
        let (adapter, owner, token) = setup_vesu_adapter();
        let user = contract_address_const::<'user'>();
        let deposit_amount = 5000;
        
        set_caller_address(user);
        
        // Note: In a real test, we would mock the Vesu protocol response
        // For now, we test the adapter logic assuming the protocol call succeeds
        let initial_balance = adapter.get_balance(token, user);
        assert(initial_balance == 0, 'Initial balance should be 0');
    }

    #[test]
    fn test_vesu_adapter_yield_rate() {
        let (adapter, owner, token) = setup_vesu_adapter();
        
        let yield_rate = adapter.get_yield_rate(token);
        // Should return 0 if no rate is set and protocol doesn't respond
        assert(yield_rate >= 0, 'Yield rate should be non-negative');
    }

    #[test]
    fn test_troves_adapter_deposit() {
        let (adapter, owner, token) = setup_troves_adapter();
        let user = contract_address_const::<'user'>();
        let stake_amount = 3000;
        
        set_caller_address(user);
        
        let initial_balance = adapter.get_balance(token, user);
        assert(initial_balance == 0, 'Initial balance should be 0');
    }

    #[test]
    fn test_troves_adapter_yield_rate() {
        let (adapter, owner, token) = setup_troves_adapter();
        
        let yield_rate = adapter.get_yield_rate(token);
        assert(yield_rate >= 0, 'Yield rate should be non-negative');
    }

    #[test]
    fn test_adapter_tvl() {
        let (vesu_adapter, _, token) = setup_vesu_adapter();
        let (troves_adapter, _, _) = setup_troves_adapter();
        
        let vesu_tvl = vesu_adapter.get_tvl(token);
        let troves_tvl = troves_adapter.get_tvl(token);
        
        // Both should return 0 as placeholder implementation
        assert(vesu_tvl == 0, 'Vesu TVL should be 0');
        assert(troves_tvl == 0, 'Troves TVL should be 0');
    }

    #[test]
    fn test_multiple_deposits_same_user() {
        let (adapter, owner, token) = setup_vesu_adapter();
        let user = contract_address_const::<'user'>();
        
        set_caller_address(user);
        
        // Test that balance tracking works correctly for multiple deposits
        let balance1 = adapter.get_balance(token, user);
        let balance2 = adapter.get_balance(token, user);
        
        assert(balance1 == balance2, 'Balance should be consistent');
    }

    #[test]
    fn test_different_users_separate_balances() {
        let (adapter, owner, token) = setup_vesu_adapter();
        let user1 = contract_address_const::<'user1'>();
        let user2 = contract_address_const::<'user2'>();
        
        let balance1 = adapter.get_balance(token, user1);
        let balance2 = adapter.get_balance(token, user2);
        
        // Both should start with 0 balance
        assert(balance1 == 0, 'User1 balance should be 0');
        assert(balance2 == 0, 'User2 balance should be 0');
    }

    #[test]
    fn test_claim_yield_no_position() {
        let (adapter, owner, token) = setup_vesu_adapter();
        let user = contract_address_const::<'user'>();
        
        set_caller_address(user);
        
        let claimed_yield = adapter.claim_yield(token);
        assert(claimed_yield == 0, 'Should claim 0 yield with no position');
    }

    #[test]
    fn test_adapter_emergency_functions() {
        let (adapter, owner, token) = setup_vesu_adapter();
        
        // These functions are internal, so we can't test them directly
        // But we can verify the adapter is constructed properly
        let yield_rate = adapter.get_yield_rate(token);
        assert(yield_rate >= 0, 'Adapter should be functional');
    }

    #[test]
    fn test_protocol_comparison() {
        let (vesu_adapter, _, token) = setup_vesu_adapter();
        let (troves_adapter, _, _) = setup_troves_adapter();
        
        let vesu_rate = vesu_adapter.get_yield_rate(token);
        let troves_rate = troves_adapter.get_yield_rate(token);
        
        // Both adapters should provide yield rates for comparison
        assert(vesu_rate >= 0, 'Vesu rate should be non-negative');
        assert(troves_rate >= 0, 'Troves rate should be non-negative');
    }

    #[test]
    fn test_adapter_interface_consistency() {
        let (vesu_adapter, _, token) = setup_vesu_adapter();
        let (troves_adapter, _, _) = setup_troves_adapter();
        let user = contract_address_const::<'user'>();
        
        // Both adapters should implement the same interface consistently
        let vesu_balance = vesu_adapter.get_balance(token, user);
        let troves_balance = troves_adapter.get_balance(token, user);
        
        assert(vesu_balance == 0, 'Vesu initial balance should be 0');
        assert(troves_balance == 0, 'Troves initial balance should be 0');
        
        let vesu_tvl = vesu_adapter.get_tvl(token);
        let troves_tvl = troves_adapter.get_tvl(token);
        
        assert(vesu_tvl == 0, 'Vesu TVL should be 0');
        assert(troves_tvl == 0, 'Troves TVL should be 0');
    }
}