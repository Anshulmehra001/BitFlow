use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use starknet::testing::{set_caller_address, set_block_timestamp};

use crate::contracts::content_pricing_manager::{
    ContentPricingManager, IContentPricingManagerDispatcher, IContentPricingManagerDispatcherTrait
};
use crate::interfaces::content_pricing::{
    PricingModel, TieredPricing, TimeDecayPricing, DynamicPricing, 
    ContentPricing, AccessAttempt
};

// Test constants
const OWNER: felt252 = 'owner';
const CREATOR: felt252 = 'creator';
const USER1: felt252 = 'user1';
const USER2: felt252 = 'user2';
const CONTENT_ID: u256 = 1;
const BASE_PRICE: u256 = 1000;
const MAX_DYNAMIC_MULTIPLIER: u256 = 2000; // 200%
const TIME_BUCKET_SIZE: u64 = 3600; // 1 hour buckets

fn setup() -> (IContentPricingManagerDispatcher, ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let owner = contract_address_const::<OWNER>();
    let creator = contract_address_const::<CREATOR>();
    let user1 = contract_address_const::<USER1>();
    let user2 = contract_address_const::<USER2>();
    
    let pricing_manager = IContentPricingManagerDispatcher {
        contract_address: starknet::deploy_syscall(
            ContentPricingManager::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![
                owner.into(),
                MAX_DYNAMIC_MULTIPLIER.into(),
                TIME_BUCKET_SIZE.into()
            ].span(),
            false,
        ).unwrap().contract_address
    };
    
    (pricing_manager, owner, creator, user1, user2)
}

#[test]
fn test_set_fixed_pricing() {
    let (pricing_manager, _, creator, _, _) = setup();
    
    set_caller_address(creator);
    
    // Set fixed pricing
    let pricing_model = PricingModel::Fixed(BASE_PRICE);
    let success = pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    assert(success, 'Setting fixed pricing failed');
    
    // Verify pricing was set
    let content_pricing = pricing_manager.get_content_pricing(CONTENT_ID);
    assert(content_pricing.content_id == CONTENT_ID, 'Wrong content ID');
    assert(content_pricing.creator == creator, 'Wrong creator');
    assert(content_pricing.is_active, 'Content should be active');
    
    // Verify price calculation
    let price = pricing_manager.get_current_price(CONTENT_ID, creator);
    assert(price == BASE_PRICE, 'Wrong fixed price');
}

#[test]
fn test_set_tiered_pricing() {
    let (pricing_manager, _, creator, user1, _) = setup();
    
    set_caller_address(creator);
    
    // Set tiered pricing
    let tiered = TieredPricing {
        tier1_threshold: 5,
        tier1_price: BASE_PRICE,
        tier2_threshold: 15,
        tier2_price: BASE_PRICE * 80 / 100, // 20% discount
        tier3_price: BASE_PRICE * 60 / 100, // 40% discount
    };
    let pricing_model = PricingModel::Tiered(tiered);
    let success = pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    assert(success, 'Setting tiered pricing failed');
    
    // Test tier 1 pricing (new user)
    let price = pricing_manager.get_current_price(CONTENT_ID, user1);
    assert(price == BASE_PRICE, 'Wrong tier 1 price');
}

#[test]
fn test_time_decay_pricing() {
    let (pricing_manager, _, creator, user1, _) = setup();
    
    set_caller_address(creator);
    
    let current_time = get_current_time();
    
    // Set time decay pricing
    let decay = TimeDecayPricing {
        initial_price: BASE_PRICE,
        decay_rate: 50, // 50 units per day
        minimum_price: BASE_PRICE / 2,
        creation_time: current_time,
    };
    let pricing_model = PricingModel::TimeBasedDecay(decay);
    let success = pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    assert(success, 'Setting time decay pricing failed');
    
    // Test initial price
    let price = pricing_manager.get_current_price(CONTENT_ID, user1);
    assert(price == BASE_PRICE, 'Wrong initial price');
    
    // Advance time by 1 day and test decay
    set_block_timestamp(current_time + 86400);
    let decayed_price = pricing_manager.get_current_price(CONTENT_ID, user1);
    assert(decayed_price == BASE_PRICE - 50, 'Wrong decayed price');
}

#[test]
fn test_dynamic_pricing() {
    let (pricing_manager, _, creator, user1, _) = setup();
    
    set_caller_address(creator);
    
    let current_time = get_current_time();
    
    // Set dynamic pricing
    let dynamic = DynamicPricing {
        base_price: BASE_PRICE,
        demand_multiplier: 1000, // 100% (no adjustment initially)
        max_price: BASE_PRICE * 2,
        adjustment_period: 3600, // 1 hour
        last_adjustment: current_time,
    };
    let pricing_model = PricingModel::DynamicDemand(dynamic);
    let success = pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    assert(success, 'Setting dynamic pricing failed');
    
    // Test initial price
    let price = pricing_manager.get_current_price(CONTENT_ID, user1);
    assert(price == BASE_PRICE, 'Wrong initial dynamic price');
}

#[test]
#[should_panic(expected: ('Unauthorized access',))]
fn test_unauthorized_pricing_update() {
    let (pricing_manager, _, creator, user1, _) = setup();
    
    // Creator sets pricing
    set_caller_address(creator);
    let pricing_model = PricingModel::Fixed(BASE_PRICE);
    pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    
    // User tries to update pricing - should panic
    set_caller_address(user1);
    let new_pricing_model = PricingModel::Fixed(BASE_PRICE * 2);
    pricing_manager.set_content_pricing(CONTENT_ID, new_pricing_model);
}

#[test]
fn test_record_access_attempt_success() {
    let (pricing_manager, _, creator, user1, _) = setup();
    
    set_caller_address(creator);
    let pricing_model = PricingModel::Fixed(BASE_PRICE);
    pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    
    // Record successful access
    let attempt_id = pricing_manager.record_access_attempt(
        CONTENT_ID,
        user1,
        BASE_PRICE,
        true,
        ''
    );
    assert(attempt_id > 0, 'Attempt ID should be positive');
    
    // Verify access statistics
    let (total_attempts, successful_accesses, total_revenue) = pricing_manager.get_access_statistics(
        CONTENT_ID,
        86400 // Last 24 hours
    );
    assert(total_attempts == 1, 'Wrong total attempts');
    assert(successful_accesses == 1, 'Wrong successful accesses');
    assert(total_revenue == BASE_PRICE, 'Wrong total revenue');
}

#[test]
fn test_record_access_attempt_failure() {
    let (pricing_manager, _, creator, user1, _) = setup();
    
    set_caller_address(creator);
    let pricing_model = PricingModel::Fixed(BASE_PRICE);
    pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    
    // Record failed access
    let attempt_id = pricing_manager.record_access_attempt(
        CONTENT_ID,
        user1,
        0,
        false,
        'insufficient_balance'
    );
    assert(attempt_id > 0, 'Attempt ID should be positive');
    
    // Verify access statistics
    let (total_attempts, successful_accesses, total_revenue) = pricing_manager.get_access_statistics(
        CONTENT_ID,
        86400 // Last 24 hours
    );
    assert(total_attempts == 1, 'Wrong total attempts');
    assert(successful_accesses == 0, 'Should have no successful accesses');
    assert(total_revenue == 0, 'Should have no revenue');
}

#[test]
fn test_can_afford_content() {
    let (pricing_manager, _, creator, user1, _) = setup();
    
    set_caller_address(creator);
    let pricing_model = PricingModel::Fixed(BASE_PRICE);
    pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    
    // Test with sufficient balance
    let can_afford = pricing_manager.can_afford_content(CONTENT_ID, user1, BASE_PRICE + 100);
    assert(can_afford, 'User should be able to afford');
    
    // Test with insufficient balance
    let cannot_afford = pricing_manager.can_afford_content(CONTENT_ID, user1, BASE_PRICE - 100);
    assert(!cannot_afford, 'User should not be able to afford');
}

#[test]
fn test_handle_payment_failure() {
    let (pricing_manager, _, creator, user1, _) = setup();
    
    set_caller_address(creator);
    let pricing_model = PricingModel::Fixed(BASE_PRICE);
    pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    
    // Test payment failure with very low balance (should block)
    let action = pricing_manager.handle_payment_failure(
        CONTENT_ID,
        user1,
        BASE_PRICE,
        BASE_PRICE / 3 // Only 33% of required amount
    );
    assert(action == 'block_access', 'Should block access');
    
    // Test payment failure with moderate shortage (should warn)
    let action = pricing_manager.handle_payment_failure(
        CONTENT_ID,
        user1,
        BASE_PRICE,
        BASE_PRICE * 70 / 100 // 70% of required amount
    );
    assert(action == 'warn_user', 'Should warn user');
    
    // Test payment failure with small shortage (should allow partial)
    let action = pricing_manager.handle_payment_failure(
        CONTENT_ID,
        user1,
        BASE_PRICE,
        BASE_PRICE * 90 / 100 // 90% of required amount
    );
    assert(action == 'allow_partial', 'Should allow partial payment');
}

#[test]
fn test_get_user_access_history() {
    let (pricing_manager, _, creator, user1, _) = setup();
    
    set_caller_address(creator);
    let pricing_model = PricingModel::Fixed(BASE_PRICE);
    pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    
    // Record multiple access attempts
    pricing_manager.record_access_attempt(CONTENT_ID, user1, BASE_PRICE, true, '');
    pricing_manager.record_access_attempt(CONTENT_ID, user1, 0, false, 'insufficient_balance');
    pricing_manager.record_access_attempt(CONTENT_ID, user1, BASE_PRICE, true, '');
    
    // Get user's access history
    let history = pricing_manager.get_user_access_history(user1, CONTENT_ID, 10);
    assert(history.len() == 3, 'Should have 3 attempts');
    
    // Verify attempt details
    let attempt1 = *history.at(0);
    let attempt2 = *history.at(1);
    let attempt3 = *history.at(2);
    
    assert(attempt1.success, 'First attempt should be successful');
    assert(!attempt2.success, 'Second attempt should be failed');
    assert(attempt3.success, 'Third attempt should be successful');
    assert(attempt2.failure_reason == 'insufficient_balance', 'Wrong failure reason');
}

#[test]
fn test_bulk_update_pricing() {
    let (pricing_manager, _, creator, _, _) = setup();
    
    set_caller_address(creator);
    
    // Prepare bulk update data
    let mut content_ids = ArrayTrait::new();
    let mut pricing_models = ArrayTrait::new();
    
    content_ids.append(1);
    content_ids.append(2);
    content_ids.append(3);
    
    pricing_models.append(PricingModel::Fixed(BASE_PRICE));
    pricing_models.append(PricingModel::Fixed(BASE_PRICE * 2));
    pricing_models.append(PricingModel::Fixed(BASE_PRICE * 3));
    
    // Perform bulk update
    let success_count = pricing_manager.bulk_update_pricing(content_ids, pricing_models);
    assert(success_count == 3, 'Should update all 3 items');
    
    // Verify updates
    let price1 = pricing_manager.get_current_price(1, creator);
    let price2 = pricing_manager.get_current_price(2, creator);
    let price3 = pricing_manager.get_current_price(3, creator);
    
    assert(price1 == BASE_PRICE, 'Wrong price for content 1');
    assert(price2 == BASE_PRICE * 2, 'Wrong price for content 2');
    assert(price3 == BASE_PRICE * 3, 'Wrong price for content 3');
}

#[test]
fn test_tiered_pricing_progression() {
    let (pricing_manager, _, creator, user1, _) = setup();
    
    set_caller_address(creator);
    
    // Set tiered pricing with clear tiers
    let tiered = TieredPricing {
        tier1_threshold: 3,
        tier1_price: BASE_PRICE,
        tier2_threshold: 6,
        tier2_price: BASE_PRICE * 80 / 100, // 20% discount
        tier3_price: BASE_PRICE * 60 / 100, // 40% discount
    };
    let pricing_model = PricingModel::Tiered(tiered);
    pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    
    // Test tier 1 pricing (new user)
    let price = pricing_manager.get_current_price(CONTENT_ID, user1);
    assert(price == BASE_PRICE, 'Wrong tier 1 price');
    
    // Record successful accesses to move to tier 2
    pricing_manager.record_access_attempt(CONTENT_ID, user1, BASE_PRICE, true, '');
    pricing_manager.record_access_attempt(CONTENT_ID, user1, BASE_PRICE, true, '');
    pricing_manager.record_access_attempt(CONTENT_ID, user1, BASE_PRICE, true, '');
    
    // Should still be tier 1 (threshold is 3, so need 3+ accesses for tier 2)
    let price = pricing_manager.get_current_price(CONTENT_ID, user1);
    assert(price == BASE_PRICE, 'Should still be tier 1 price');
    
    // Add one more access to reach tier 2
    pricing_manager.record_access_attempt(CONTENT_ID, user1, BASE_PRICE, true, '');
    
    // Should now be tier 2
    let price = pricing_manager.get_current_price(CONTENT_ID, user1);
    assert(price == BASE_PRICE * 80 / 100, 'Should be tier 2 price');
}

#[test]
fn test_update_dynamic_pricing() {
    let (pricing_manager, _, creator, user1, _) = setup();
    
    set_caller_address(creator);
    
    let current_time = get_current_time();
    
    // Set dynamic pricing
    let dynamic = DynamicPricing {
        base_price: BASE_PRICE,
        demand_multiplier: 1000, // 100%
        max_price: BASE_PRICE * 2,
        adjustment_period: 3600, // 1 hour
        last_adjustment: current_time - 3600, // Last adjusted 1 hour ago
    };
    let pricing_model = PricingModel::DynamicDemand(dynamic);
    pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    
    // Record some successful accesses to create demand
    let mut i = 0;
    while i < 15 {
        pricing_manager.record_access_attempt(CONTENT_ID, user1, BASE_PRICE, true, '');
        i += 1;
    };
    
    // Update dynamic pricing (should increase due to high demand)
    let new_price = pricing_manager.update_dynamic_pricing(CONTENT_ID);
    assert(new_price > BASE_PRICE, 'Price should increase due to demand');
}

#[test]
#[should_panic(expected: ('Content does not use dynamic pricing',))]
fn test_update_dynamic_pricing_wrong_model() {
    let (pricing_manager, _, creator, _, _) = setup();
    
    set_caller_address(creator);
    
    // Set fixed pricing (not dynamic)
    let pricing_model = PricingModel::Fixed(BASE_PRICE);
    pricing_manager.set_content_pricing(CONTENT_ID, pricing_model);
    
    // Try to update dynamic pricing - should panic
    pricing_manager.update_dynamic_pricing(CONTENT_ID);
}