use starknet::{ContractAddress, contract_address_const};
use starknet::testing::set_caller_address;

use crate::contracts::integrated_micro_payment_system::{
    IntegratedMicroPaymentSystem, IIntegratedMicroPaymentSystemDispatcher, 
    IIntegratedMicroPaymentSystemDispatcherTrait
};
use crate::contracts::micro_payment_manager::{
    MicroPaymentManager, IMicroPaymentManagerDispatcher, IMicroPaymentManagerDispatcherTrait
};
use crate::contracts::content_pricing_manager::{
    ContentPricingManager, IContentPricingManagerDispatcher, IContentPricingManagerDispatcherTrait
};
use crate::contracts::stream_manager::{
    StreamManager, IStreamManagerDispatcher, IStreamManagerDispatcherTrait
};
use crate::interfaces::content_pricing::PricingModel;

// Test constants
const OWNER: felt252 = 'owner';
const CREATOR: felt252 = 'creator';
const USER: felt252 = 'user';
const CONTENT_ID: u256 = 1;
const BASE_PRICE: u256 = 1000;

fn setup() -> (IIntegratedMicroPaymentSystemDispatcher, ContractAddress, ContractAddress, ContractAddress) {
    let owner = contract_address_const::<OWNER>();
    let creator = contract_address_const::<CREATOR>();
    let user = contract_address_const::<USER>();
    
    // Deploy component contracts first
    let stream_manager = IStreamManagerDispatcher {
        contract_address: starknet::deploy_syscall(
            StreamManager::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![owner.into()].span(),
            false,
        ).unwrap().contract_address
    };
    
    let micro_payment_manager = IMicroPaymentManagerDispatcher {
        contract_address: starknet::deploy_syscall(
            MicroPaymentManager::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![
                owner.into(),
                stream_manager.contract_address.into(),
                100_u256.into() // min payment
            ].span(),
            false,
        ).unwrap().contract_address
    };
    
    let content_pricing_manager = IContentPricingManagerDispatcher {
        contract_address: starknet::deploy_syscall(
            ContentPricingManager::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![
                owner.into(),
                2000_u256.into(), // max multiplier
                3600_u64.into()   // time bucket
            ].span(),
            false,
        ).unwrap().contract_address
    };
    
    // Deploy integrated system
    let integrated_system = IIntegratedMicroPaymentSystemDispatcher {
        contract_address: starknet::deploy_syscall(
            IntegratedMicroPaymentSystem::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![
                owner.into(),
                micro_payment_manager.contract_address.into(),
                content_pricing_manager.contract_address.into(),
                stream_manager.contract_address.into()
            ].span(),
            false,
        ).unwrap().contract_address
    };
    
    (integrated_system, owner, creator, user)
}

#[test]
fn test_setup_content_with_fixed_pricing() {
    let (integrated_system, _, creator, _) = setup();
    
    set_caller_address(creator);
    
    let pricing_model = PricingModel::Fixed(BASE_PRICE);
    let success = integrated_system.setup_content_with_pricing(CONTENT_ID, pricing_model);
    assert(success, 'Content setup failed');
}