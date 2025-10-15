use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use starknet::testing::{set_caller_address, set_block_timestamp};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use bitflow::interfaces::subscription_manager::{ISubscriptionManagerDispatcher, ISubscriptionManagerDispatcherTrait};
use bitflow::interfaces::stream_manager::{IStreamManagerDispatcher, IStreamManagerDispatcherTrait};
use bitflow::types::{SubscriptionStatus};

fn deploy_contracts() -> (ISubscriptionManagerDispatcher, IStreamManagerDispatcher, ContractAddress, ContractAddress) {
    // Deploy mock stream manager first
    let stream_manager_class = declare("StreamManager").unwrap().contract_class();
    let escrow_manager_address = contract_address_const::<0x123>();
    let bridge_adapter_address = contract_address_const::<0x456>();
    let yield_manager_address = contract_address_const::<0x789>();
    let owner = contract_address_const::<0x999>();
    
    let mut stream_manager_constructor_calldata = array![];
    escrow_manager_address.serialize(ref stream_manager_constructor_calldata);
    bridge_adapter_address.serialize(ref stream_manager_constructor_calldata);
    yield_manager_address.serialize(ref stream_manager_constructor_calldata);
    owner.serialize(ref stream_manager_constructor_calldata);
    
    let (stream_manager_address, _) = stream_manager_class.deploy(@stream_manager_constructor_calldata).unwrap();
    let stream_manager = IStreamManagerDispatcher { contract_address: stream_manager_address };
    
    // Deploy subscription manager
    let subscription_manager_class = declare("SubscriptionManager").unwrap().contract_class();
    let mut constructor_calldata = array![];
    stream_manager_address.serialize(ref constructor_calldata);
    owner.serialize(ref constructor_calldata);
    
    let (subscription_manager_address, _) = subscription_manager_class.deploy(@constructor_calldata).unwrap();
    let subscription_manager = ISubscriptionManagerDispatcher { contract_address: subscription_manager_address };
    
    let provider = contract_address_const::<0x111>();
    let subscriber = contract_address_const::<0x222>();
    
    (subscription_manager, stream_manager, provider, subscriber)
}

#[test]
fn test_create_subscription_plan() {
    let (subscription_manager, _, provider, _) = deploy_contracts();
    
    set_caller_address(provider);
    set_block_timestamp(1000);
    
    let plan_id = subscription_manager.create_subscription_plan(
        1000, // price: 1000 wei per period
        86400, // interval: 1 day
        100, // max_subscribers
        'test_plan' // metadata
    );
    
    assert(plan_id == 1, 'Plan ID should be 1');
    
    let (price, interval, max_subscribers, current_subscribers) = subscription_manager.get_subscription_plan(plan_id);
    assert(price == 1000, 'Price should be 1000');
    assert(interval == 86400, 'Interval should be 86400');
    assert(max_subscribers == 100, 'Max subscribers should be 100');
    assert(current_subscribers == 0, 'Current subscribers should be 0');
}

#[test]
#[should_panic(expected: ('Price must be greater than 0',))]
fn test_create_subscription_plan_zero_price() {
    let (subscription_manager, _, provider, _) = deploy_contracts();
    
    set_caller_address(provider);
    
    subscription_manager.create_subscription_plan(
        0, // invalid price
        86400,
        100,
        'test_plan'
    );
}

#[test]
#[should_panic(expected: ('Interval must be greater than 0',))]
fn test_create_subscription_plan_zero_interval() {
    let (subscription_manager, _, provider, _) = deploy_contracts();
    
    set_caller_address(provider);
    
    subscription_manager.create_subscription_plan(
        1000,
        0, // invalid interval
        100,
        'test_plan'
    );
}

#[test]
fn test_subscribe_to_plan() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create a plan first
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(
        1000, // 1000 wei per day
        86400, // 1 day interval
        100,
        'test_plan'
    );
    
    // Subscribe to the plan
    set_caller_address(subscriber);
    set_block_timestamp(2000);
    
    let subscription_id = subscription_manager.subscribe(
        plan_id,
        30, // 30 periods (30 days)
        true // auto_renew
    );
    
    assert(subscription_id == 1, 'Subscription ID should be 1');
    
    let subscription = subscription_manager.get_subscription(subscription_id);
    assert(subscription.id == subscription_id, 'Subscription ID mismatch');
    assert(subscription.plan_id == plan_id, 'Plan ID mismatch');
    assert(subscription.subscriber == subscriber, 'Subscriber mismatch');
    assert(subscription.provider == provider, 'Provider mismatch');
    assert(subscription.auto_renew == true, 'Auto renew should be true');
    assert(subscription.status == SubscriptionStatus::Active, 'Status should be Active');
    
    // Check plan analytics
    let (total_revenue, active_subscribers, total_subscribers) = subscription_manager.get_plan_analytics(plan_id);
    assert(total_revenue == 30000, 'Total revenue should be 30000'); // 1000 * 30
    assert(active_subscribers == 1, 'Active subscribers should be 1');
    assert(total_subscribers == 1, 'Total subscribers should be 1');
}

#[test]
#[should_panic(expected: ('Plan is not active',))]
fn test_subscribe_to_inactive_plan() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    set_caller_address(subscriber);
    
    // Try to subscribe to non-existent plan
    subscription_manager.subscribe(
        999, // non-existent plan
        30,
        true
    );
}

#[test]
fn test_cancel_subscription() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan and subscription
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    set_caller_address(subscriber);
    let subscription_id = subscription_manager.subscribe(plan_id, 30, true);
    
    // Cancel subscription
    let success = subscription_manager.cancel_subscription(subscription_id);
    assert(success, 'Cancellation should succeed');
    
    let status = subscription_manager.get_subscription_status(subscription_id);
    assert(status == SubscriptionStatus::Cancelled, 'Status should be Cancelled');
    
    // Check plan subscriber count decreased
    let (_, _, _, current_subscribers) = subscription_manager.get_subscription_plan(plan_id);
    assert(current_subscribers == 0, 'Current subscribers should be 0');
}

#[test]
#[should_panic(expected: ('Unauthorized',))]
fn test_cancel_subscription_unauthorized() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan and subscription
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    set_caller_address(subscriber);
    let subscription_id = subscription_manager.subscribe(plan_id, 30, true);
    
    // Try to cancel from unauthorized address
    let unauthorized = contract_address_const::<0x333>();
    set_caller_address(unauthorized);
    subscription_manager.cancel_subscription(subscription_id);
}

#[test]
fn test_pause_and_resume_subscription() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan and subscription
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    set_caller_address(subscriber);
    let subscription_id = subscription_manager.subscribe(plan_id, 30, true);
    
    // Pause subscription
    let success = subscription_manager.pause_subscription(subscription_id);
    assert(success, 'Pause should succeed');
    
    let status = subscription_manager.get_subscription_status(subscription_id);
    assert(status == SubscriptionStatus::Paused, 'Status should be Paused');
    
    // Resume subscription
    let success = subscription_manager.resume_subscription(subscription_id);
    assert(success, 'Resume should succeed');
    
    let status = subscription_manager.get_subscription_status(subscription_id);
    assert(status == SubscriptionStatus::Active, 'Status should be Active');
}

#[test]
#[should_panic(expected: ('Subscription not active',))]
fn test_pause_inactive_subscription() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan and subscription
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    set_caller_address(subscriber);
    let subscription_id = subscription_manager.subscribe(plan_id, 30, true);
    
    // Cancel first
    subscription_manager.cancel_subscription(subscription_id);
    
    // Try to pause cancelled subscription
    subscription_manager.pause_subscription(subscription_id);
}

#[test]
fn test_renew_subscription() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan and subscription
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    set_caller_address(subscriber);
    set_block_timestamp(2000);
    let subscription_id = subscription_manager.subscribe(plan_id, 1, false); // 1 period, no auto-renew
    
    let original_subscription = subscription_manager.get_subscription(subscription_id);
    let original_end_time = original_subscription.end_time;
    
    // Renew for 2 more periods
    let success = subscription_manager.renew_subscription(subscription_id, 2);
    assert(success, 'Renewal should succeed');
    
    let renewed_subscription = subscription_manager.get_subscription(subscription_id);
    assert(renewed_subscription.end_time > original_end_time, 'End time should be extended');
    
    // Check analytics updated
    let (total_revenue, _, _) = subscription_manager.get_plan_analytics(plan_id);
    assert(total_revenue == 3000, 'Total revenue should be 3000'); // 1000 * (1 + 2)
}

#[test]
fn test_update_subscription_plan() {
    let (subscription_manager, _, provider, _) = deploy_contracts();
    
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    // Update plan
    let success = subscription_manager.update_subscription_plan(plan_id, 1500, 200);
    assert(success, 'Update should succeed');
    
    let (price, interval, max_subscribers, current_subscribers) = subscription_manager.get_subscription_plan(plan_id);
    assert(price == 1500, 'Price should be updated to 1500');
    assert(max_subscribers == 200, 'Max subscribers should be updated to 200');
    assert(interval == 86400, 'Interval should remain unchanged');
    assert(current_subscribers == 0, 'Current subscribers should remain 0');
}

#[test]
#[should_panic(expected: ('Unauthorized',))]
fn test_update_subscription_plan_unauthorized() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    // Try to update from unauthorized address
    set_caller_address(subscriber);
    subscription_manager.update_subscription_plan(plan_id, 1500, 200);
}

#[test]
fn test_get_user_subscriptions() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    // Create multiple subscriptions
    set_caller_address(subscriber);
    let sub_id_1 = subscription_manager.subscribe(plan_id, 30, true);
    let sub_id_2 = subscription_manager.subscribe(plan_id, 60, false);
    
    let user_subscriptions = subscription_manager.get_user_subscriptions(subscriber);
    assert(user_subscriptions.len() == 2, 'Should have 2 subscriptions');
    assert(*user_subscriptions.at(0) == sub_id_1, 'First subscription ID mismatch');
    assert(*user_subscriptions.at(1) == sub_id_2, 'Second subscription ID mismatch');
}

#[test]
fn test_get_plan_subscriptions() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    // Create subscriptions from different users
    set_caller_address(subscriber);
    let sub_id_1 = subscription_manager.subscribe(plan_id, 30, true);
    
    let subscriber_2 = contract_address_const::<0x333>();
    set_caller_address(subscriber_2);
    let sub_id_2 = subscription_manager.subscribe(plan_id, 60, false);
    
    let plan_subscriptions = subscription_manager.get_plan_subscriptions(plan_id);
    assert(plan_subscriptions.len() == 2, 'Should have 2 subscriptions');
    assert(*plan_subscriptions.at(0) == sub_id_1, 'First subscription ID mismatch');
    assert(*plan_subscriptions.at(1) == sub_id_2, 'Second subscription ID mismatch');
}

#[test]
fn test_subscription_expiry_status() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan and subscription
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    set_caller_address(subscriber);
    set_block_timestamp(2000);
    let subscription_id = subscription_manager.subscribe(plan_id, 1, false); // 1 day subscription
    
    // Check status before expiry
    let status = subscription_manager.get_subscription_status(subscription_id);
    assert(status == SubscriptionStatus::Active, 'Should be Active before expiry');
    
    // Move time forward past expiry
    set_block_timestamp(2000 + 86400 + 1); // Past the end time
    
    let status = subscription_manager.get_subscription_status(subscription_id);
    assert(status == SubscriptionStatus::Expired, 'Should be Expired after end time');
}

#[test]
fn test_process_auto_renewals() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan and subscription with auto-renew
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    set_caller_address(subscriber);
    set_block_timestamp(2000);
    let subscription_id = subscription_manager.subscribe(plan_id, 1, true); // 1 day, auto-renew
    
    // Move time forward past expiry
    set_block_timestamp(2000 + 86400 + 1);
    
    // Process auto renewals
    let renewed_count = subscription_manager.process_auto_renewals(10);
    assert(renewed_count == 1, 'Should have renewed 1 subscription');
    
    // Check subscription was renewed
    let subscription = subscription_manager.get_subscription(subscription_id);
    assert(subscription.end_time > 2000 + 86400, 'End time should be extended');
    
    // Check analytics updated
    let (total_revenue, _, _) = subscription_manager.get_plan_analytics(plan_id);
    assert(total_revenue == 2000, 'Total revenue should be 2000'); // Original 1000 + renewal 1000
}

#[test]
fn test_plan_analytics() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    // Initial analytics should be zero
    let (total_revenue, active_subscribers, total_subscribers) = subscription_manager.get_plan_analytics(plan_id);
    assert(total_revenue == 0, 'Initial revenue should be 0');
    assert(active_subscribers == 0, 'Initial active subscribers should be 0');
    assert(total_subscribers == 0, 'Initial total subscribers should be 0');
    
    // Add subscribers
    set_caller_address(subscriber);
    subscription_manager.subscribe(plan_id, 30, true); // 30000 revenue
    
    let subscriber_2 = contract_address_const::<0x333>();
    set_caller_address(subscriber_2);
    subscription_manager.subscribe(plan_id, 60, false); // 60000 revenue
    
    // Check updated analytics
    let (total_revenue, active_subscribers, total_subscribers) = subscription_manager.get_plan_analytics(plan_id);
    assert(total_revenue == 90000, 'Total revenue should be 90000');
    assert(active_subscribers == 2, 'Active subscribers should be 2');
    assert(total_subscribers == 2, 'Total subscribers should be 2');
    
    // Cancel one subscription
    set_caller_address(subscriber);
    subscription_manager.cancel_subscription(1);
    
    // Check analytics after cancellation
    let (total_revenue, active_subscribers, total_subscribers) = subscription_manager.get_plan_analytics(plan_id);
    assert(total_revenue == 90000, 'Total revenue should remain 90000');
    assert(active_subscribers == 1, 'Active subscribers should be 1');
    assert(total_subscribers == 2, 'Total subscribers should remain 2');
}

#[test]
fn test_plan_status_breakdown() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    // Create multiple subscriptions
    set_caller_address(subscriber);
    let sub_id_1 = subscription_manager.subscribe(plan_id, 30, true);
    let sub_id_2 = subscription_manager.subscribe(plan_id, 60, false);
    
    let subscriber_2 = contract_address_const::<0x333>();
    set_caller_address(subscriber_2);
    let sub_id_3 = subscription_manager.subscribe(plan_id, 15, false);
    
    // Initial status breakdown - all should be active
    let (active, paused, cancelled, expired) = subscription_manager.get_plan_status_breakdown(plan_id);
    assert(active == 3, 'Should have 3 active subscriptions');
    assert(paused == 0, 'Should have 0 paused subscriptions');
    assert(cancelled == 0, 'Should have 0 cancelled subscriptions');
    assert(expired == 0, 'Should have 0 expired subscriptions');
    
    // Pause one subscription
    set_caller_address(subscriber);
    subscription_manager.pause_subscription(sub_id_1);
    
    // Cancel one subscription
    set_caller_address(subscriber_2);
    subscription_manager.cancel_subscription(sub_id_3);
    
    // Check updated breakdown
    let (active, paused, cancelled, expired) = subscription_manager.get_plan_status_breakdown(plan_id);
    assert(active == 1, 'Should have 1 active subscription');
    assert(paused == 1, 'Should have 1 paused subscription');
    assert(cancelled == 1, 'Should have 1 cancelled subscription');
    assert(expired == 0, 'Should have 0 expired subscriptions');
}

#[test]
fn test_plan_renewal_stats() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan and subscription
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    set_caller_address(subscriber);
    let subscription_id = subscription_manager.subscribe(plan_id, 1, true); // Auto-renew enabled
    
    // Initial renewal stats should be zero
    let (total, auto, manual) = subscription_manager.get_plan_renewal_stats(plan_id);
    assert(total == 0, 'Initial total renewals should be 0');
    assert(auto == 0, 'Initial auto renewals should be 0');
    assert(manual == 0, 'Initial manual renewals should be 0');
    
    // Manual renewal
    subscription_manager.renew_subscription(subscription_id, 2);
    
    let (total, auto, manual) = subscription_manager.get_plan_renewal_stats(plan_id);
    assert(total == 1, 'Total renewals should be 1');
    assert(auto == 0, 'Auto renewals should be 0');
    assert(manual == 1, 'Manual renewals should be 1');
    
    // Simulate auto renewal
    set_block_timestamp(2000 + 86400 + 1); // Past expiry
    subscription_manager.process_auto_renewals(10);
    
    let (total, auto, manual) = subscription_manager.get_plan_renewal_stats(plan_id);
    assert(total == 2, 'Total renewals should be 2');
    assert(auto == 1, 'Auto renewals should be 1');
    assert(manual == 1, 'Manual renewals should remain 1');
}

#[test]
fn test_platform_analytics() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Initial platform analytics should be zero
    let (total_plans, total_subs, total_revenue, active_subs) = subscription_manager.get_platform_analytics();
    assert(total_plans == 0, 'Initial plans should be 0');
    assert(total_subs == 0, 'Initial subscriptions should be 0');
    assert(total_revenue == 0, 'Initial revenue should be 0');
    assert(active_subs == 0, 'Initial active subs should be 0');
    
    // Create multiple plans
    set_caller_address(provider);
    let plan_id_1 = subscription_manager.create_subscription_plan(1000, 86400, 100, 'plan_1');
    let plan_id_2 = subscription_manager.create_subscription_plan(2000, 172800, 50, 'plan_2');
    
    // Create subscriptions
    set_caller_address(subscriber);
    subscription_manager.subscribe(plan_id_1, 30, true); // 30000 revenue
    subscription_manager.subscribe(plan_id_2, 10, false); // 20000 revenue
    
    let subscriber_2 = contract_address_const::<0x333>();
    set_caller_address(subscriber_2);
    subscription_manager.subscribe(plan_id_1, 15, false); // 15000 revenue
    
    // Check platform analytics
    let (total_plans, total_subs, total_revenue, active_subs) = subscription_manager.get_platform_analytics();
    assert(total_plans == 2, 'Should have 2 plans');
    assert(total_subs == 3, 'Should have 3 subscriptions');
    assert(total_revenue == 65000, 'Total revenue should be 65000');
    assert(active_subs == 3, 'Should have 3 active subscriptions');
    
    // Cancel one subscription
    set_caller_address(subscriber);
    subscription_manager.cancel_subscription(1);
    
    // Check updated analytics
    let (total_plans, total_subs, total_revenue, active_subs) = subscription_manager.get_platform_analytics();
    assert(total_plans == 2, 'Plans should remain 2');
    assert(total_subs == 3, 'Total subscriptions should remain 3');
    assert(total_revenue == 65000, 'Revenue should remain 65000');
    assert(active_subs == 2, 'Active subscriptions should be 2');
}

#[test]
fn test_plan_churn_rate() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    // Initial churn rate should be 0
    let churn_rate = subscription_manager.get_plan_churn_rate(plan_id);
    assert(churn_rate == 0, 'Initial churn rate should be 0');
    
    // Create 4 subscriptions
    set_caller_address(subscriber);
    let sub_id_1 = subscription_manager.subscribe(plan_id, 30, true);
    let sub_id_2 = subscription_manager.subscribe(plan_id, 60, false);
    
    let subscriber_2 = contract_address_const::<0x333>();
    set_caller_address(subscriber_2);
    let sub_id_3 = subscription_manager.subscribe(plan_id, 15, false);
    let sub_id_4 = subscription_manager.subscribe(plan_id, 45, true);
    
    // Cancel 1 out of 4 subscriptions (25% churn)
    subscription_manager.cancel_subscription(sub_id_3);
    
    let churn_rate = subscription_manager.get_plan_churn_rate(plan_id);
    assert(churn_rate == 2500, 'Churn rate should be 2500 (25.00%)');
    
    // Cancel another subscription (50% churn)
    set_caller_address(subscriber);
    subscription_manager.cancel_subscription(sub_id_1);
    
    let churn_rate = subscription_manager.get_plan_churn_rate(plan_id);
    assert(churn_rate == 5000, 'Churn rate should be 5000 (50.00%)');
}

#[test]
fn test_plan_avg_duration() {
    let (subscription_manager, _, provider, subscriber) = deploy_contracts();
    
    // Create plan with 1 day interval
    set_caller_address(provider);
    let plan_id = subscription_manager.create_subscription_plan(1000, 86400, 100, 'test_plan');
    
    // Initial average duration should be 0
    let avg_duration = subscription_manager.get_plan_avg_duration(plan_id);
    assert(avg_duration == 0, 'Initial avg duration should be 0');
    
    // Create subscriptions with different durations
    set_caller_address(subscriber);
    subscription_manager.subscribe(plan_id, 30, true); // 30 days = 2,592,000 seconds
    
    let subscriber_2 = contract_address_const::<0x333>();
    set_caller_address(subscriber_2);
    subscription_manager.subscribe(plan_id, 60, false); // 60 days = 5,184,000 seconds
    
    // Average should be (30 + 60) / 2 = 45 days = 3,888,000 seconds
    let avg_duration = subscription_manager.get_plan_avg_duration(plan_id);
    assert(avg_duration == 3888000, 'Avg duration should be 3888000 seconds');
    
    // Add another subscription
    let subscriber_3 = contract_address_const::<0x444>();
    set_caller_address(subscriber_3);
    subscription_manager.subscribe(plan_id, 15, false); // 15 days = 1,296,000 seconds
    
    // Average should be (30 + 60 + 15) / 3 = 35 days = 3,024,000 seconds
    let avg_duration = subscription_manager.get_plan_avg_duration(plan_id);
    assert(avg_duration == 3024000, 'Avg duration should be 3024000 seconds');
}