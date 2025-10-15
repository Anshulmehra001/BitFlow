use bitflow::utils::{math, validation, time};
use bitflow::types::{PaymentStream, Subscription, YieldPosition, SubscriptionStatus, BitFlowError};
use starknet::ContractAddress;
use starknet::contract_address_const;

#[test]
fn test_calculate_available_amount() {
    let total_amount = 1000_u256;
    let rate_per_second = 10_u256;
    let start_time = 100_u64;
    let current_time = 150_u64; // 50 seconds elapsed
    let withdrawn_amount = 200_u256;
    
    let available = math::calculate_available_amount(
        total_amount,
        rate_per_second,
        start_time,
        current_time,
        withdrawn_amount
    );
    
    // 50 seconds * 10 per second = 500 total streamed
    // 500 - 200 withdrawn = 300 available
    assert(available == 300, 'Incorrect available amount');
}

#[test]
fn test_calculate_available_amount_before_start() {
    let total_amount = 1000_u256;
    let rate_per_second = 10_u256;
    let start_time = 200_u64;
    let current_time = 150_u64; // Before start time
    let withdrawn_amount = 0_u256;
    
    let available = math::calculate_available_amount(
        total_amount,
        rate_per_second,
        start_time,
        current_time,
        withdrawn_amount
    );
    
    assert(available == 0, 'Should be 0 before start');
}

#[test]
fn test_calculate_rate_per_second() {
    let total_amount = 3600_u256;
    let duration = 3600_u64; // 1 hour
    
    let rate = math::calculate_rate_per_second(total_amount, duration);
    assert(rate == 1, 'Rate should be 1 per second');
}

#[test]
fn test_calculate_yield() {
    let principal = 10000_u256;
    let annual_rate = 500_u256; // 5% in basis points
    let time_period = 31536000_u64; // 1 year in seconds
    
    let yield_earned = math::calculate_yield(principal, annual_rate, time_period);
    assert(yield_earned == 500, 'Yield should be 500 for 5% annual');
}

#[test]
fn test_validate_stream_parameters_valid() {
    let recipient = contract_address_const::<0x123>();
    let amount = 1000_u256;
    let rate = 10_u256;
    let duration = 100_u64;
    
    let result = validation::validate_stream_parameters(recipient, amount, rate, duration);
    assert(result.is_ok(), 'Valid parameters should pass');
}

#[test]
fn test_validate_stream_parameters_zero_amount() {
    let recipient = contract_address_const::<0x123>();
    let amount = 0_u256;
    let rate = 10_u256;
    let duration = 100_u64;
    
    let result = validation::validate_stream_parameters(recipient, amount, rate, duration);
    assert(result.is_err(), 'Zero amount should fail');
}

#[test]
fn test_validate_stream_parameters_zero_address() {
    let recipient = contract_address_const::<0x0>();
    let amount = 1000_u256;
    let rate = 10_u256;
    let duration = 100_u64;
    
    let result = validation::validate_stream_parameters(recipient, amount, rate, duration);
    assert(result.is_err(), 'Zero address should fail');
}

#[test]
fn test_safe_add_normal() {
    let a = 100_u256;
    let b = 200_u256;
    let result = math::safe_add(a, b);
    assert(result == 300, 'Normal addition should work');
}

#[test]
fn test_safe_sub_normal() {
    let a = 300_u256;
    let b = 100_u256;
    let result = math::safe_sub(a, b);
    assert(result == 200, 'Normal subtraction should work');
}

#[test]
fn test_safe_sub_underflow() {
    let a = 100_u256;
    let b = 300_u256;
    let result = math::safe_sub(a, b);
    assert(result == 0, 'Underflow should return 0');
}

#[test]
fn test_days_to_seconds() {
    let days = 1_u64;
    let seconds = time::days_to_seconds(days);
    assert(seconds == 86400, 'One day should be 86400 seconds');
}

#[test]
fn test_hours_to_seconds() {
    let hours = 1_u64;
    let seconds = time::hours_to_seconds(hours);
    assert(seconds == 3600, 'One hour should be 3600 seconds');
}

#[test]
fn test_minutes_to_seconds() {
    let minutes = 1_u64;
    let seconds = time::minutes_to_seconds(minutes);
    assert(seconds == 60, 'One minute should be 60 seconds');
}

// Subscription validation tests

#[test]
fn test_validate_subscription_creation_valid() {
    let subscriber = contract_address_const::<0x123>();
    let provider = contract_address_const::<0x456>();
    let duration = 2592000_u64; // 30 days
    let current_time = 1000_u64;
    
    let result = validation::validate_subscription_creation(subscriber, provider, duration, current_time);
    assert(result.is_ok(), 'Valid subscription should pass');
}

#[test]
fn test_validate_subscription_creation_same_addresses() {
    let address = contract_address_const::<0x123>();
    let duration = 2592000_u64; // 30 days
    let current_time = 1000_u64;
    
    let result = validation::validate_subscription_creation(address, address, duration, current_time);
    assert(result.is_err(), 'Same subscriber/provider should fail');
}

#[test]
fn test_validate_subscription_creation_zero_duration() {
    let subscriber = contract_address_const::<0x123>();
    let provider = contract_address_const::<0x456>();
    let duration = 0_u64;
    let current_time = 1000_u64;
    
    let result = validation::validate_subscription_creation(subscriber, provider, duration, current_time);
    assert(result.is_err(), 'Zero duration should fail');
}

#[test]
fn test_validate_subscription_lifecycle_active_to_paused() {
    let subscription = Subscription {
        id: 1_u256,
        plan_id: 1_u256,
        subscriber: contract_address_const::<0x123>(),
        provider: contract_address_const::<0x456>(),
        stream_id: 1_u256,
        start_time: 1000_u64,
        end_time: 2000_u64,
        auto_renew: false,
        status: SubscriptionStatus::Active,
    };
    
    let result = validation::validate_subscription_lifecycle(
        subscription, 
        SubscriptionStatus::Paused, 
        1500_u64
    );
    assert(result.is_ok(), 'Active to Paused should be valid');
}

#[test]
fn test_validate_subscription_lifecycle_cancelled_to_active() {
    let subscription = Subscription {
        id: 1_u256,
        plan_id: 1_u256,
        subscriber: contract_address_const::<0x123>(),
        provider: contract_address_const::<0x456>(),
        stream_id: 1_u256,
        start_time: 1000_u64,
        end_time: 2000_u64,
        auto_renew: false,
        status: SubscriptionStatus::Cancelled,
    };
    
    let result = validation::validate_subscription_lifecycle(
        subscription, 
        SubscriptionStatus::Active, 
        1500_u64
    );
    assert(result.is_err(), 'Cancelled to Active should fail');
}

#[test]
fn test_validate_subscription_lifecycle_expired_to_active_with_autorenew() {
    let subscription = Subscription {
        id: 1_u256,
        plan_id: 1_u256,
        subscriber: contract_address_const::<0x123>(),
        provider: contract_address_const::<0x456>(),
        stream_id: 1_u256,
        start_time: 1000_u64,
        end_time: 2000_u64,
        auto_renew: true,
        status: SubscriptionStatus::Expired,
    };
    
    let result = validation::validate_subscription_lifecycle(
        subscription, 
        SubscriptionStatus::Active, 
        2500_u64
    );
    assert(result.is_ok(), 'Expired to Active with auto-renew should be valid');
}

// YieldPosition validation tests

#[test]
fn test_validate_yield_position_valid() {
    let yield_position = YieldPosition {
        stream_id: 1_u256,
        protocol: contract_address_const::<0x789>(),
        staked_amount: 1000_u256,
        earned_yield: 50_u256,
        last_update: 1000_u64,
    };
    
    let result = validation::validate_yield_position(yield_position, 1500_u64);
    assert(result.is_ok(), 'Valid yield position should pass');
}

#[test]
fn test_validate_yield_position_zero_stream_id() {
    let yield_position = YieldPosition {
        stream_id: 0_u256,
        protocol: contract_address_const::<0x789>(),
        staked_amount: 1000_u256,
        earned_yield: 50_u256,
        last_update: 1000_u64,
    };
    
    let result = validation::validate_yield_position(yield_position, 1500_u64);
    assert(result.is_err(), 'Zero stream_id should fail');
}

#[test]
fn test_validate_yield_position_zero_staked_amount() {
    let yield_position = YieldPosition {
        stream_id: 1_u256,
        protocol: contract_address_const::<0x789>(),
        staked_amount: 0_u256,
        earned_yield: 50_u256,
        last_update: 1000_u64,
    };
    
    let result = validation::validate_yield_position(yield_position, 1500_u64);
    assert(result.is_err(), 'Zero staked amount should fail');
}

#[test]
fn test_validate_yield_position_future_update() {
    let yield_position = YieldPosition {
        stream_id: 1_u256,
        protocol: contract_address_const::<0x789>(),
        staked_amount: 1000_u256,
        earned_yield: 50_u256,
        last_update: 2000_u64,
    };
    
    let result = validation::validate_yield_position(yield_position, 1500_u64);
    assert(result.is_err(), 'Future last_update should fail');
}

#[test]
fn test_validate_yield_position_update_valid() {
    let old_position = YieldPosition {
        stream_id: 1_u256,
        protocol: contract_address_const::<0x789>(),
        staked_amount: 1000_u256,
        earned_yield: 50_u256,
        last_update: 1000_u64,
    };
    
    let result = validation::validate_yield_position_update(
        old_position,
        1200_u256, // increased stake
        75_u256,   // increased yield
        1500_u64   // later time
    );
    assert(result.is_ok(), 'Valid yield position update should pass');
}

#[test]
fn test_validate_yield_position_update_decreased_yield() {
    let old_position = YieldPosition {
        stream_id: 1_u256,
        protocol: contract_address_const::<0x789>(),
        staked_amount: 1000_u256,
        earned_yield: 50_u256,
        last_update: 1000_u64,
    };
    
    let result = validation::validate_yield_position_update(
        old_position,
        1200_u256, // increased stake
        25_u256,   // decreased yield (should fail)
        1500_u64   // later time
    );
    assert(result.is_err(), 'Decreased yield should fail');
}

#[test]
fn test_validate_yield_position_update_time_regression() {
    let old_position = YieldPosition {
        stream_id: 1_u256,
        protocol: contract_address_const::<0x789>(),
        staked_amount: 1000_u256,
        earned_yield: 50_u256,
        last_update: 1000_u64,
    };
    
    let result = validation::validate_yield_position_update(
        old_position,
        1200_u256, // increased stake
        75_u256,   // increased yield
        500_u64    // earlier time (should fail)
    );
    assert(result.is_err(), 'Time regression should fail');
}