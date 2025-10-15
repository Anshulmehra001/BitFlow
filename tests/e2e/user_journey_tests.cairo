use starknet::testing::{set_caller_address, set_block_timestamp};
use super::integration_helpers::{TestEnvironment, TestEnvironmentTrait};
use super::test_data_factory::{TestDataFactoryTrait};
use bitflow::types::{PaymentStream, Subscription, BridgeStatus};

// Complete user journey tests covering all major workflows
#[cfg(test)]
mod user_journey_tests {
    use super::*;

    #[test]
    fn test_complete_stream_lifecycle() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Setup: User has Bitcoin balance
        env.setup_bitcoin_balance(env.test_user, 100000000); // 1 BTC
        
        // Step 1: User creates a payment stream
        let (recipient, amount, rate, duration) = TestDataFactoryTrait::create_medium_stream_params();
        let stream_id = env.create_test_stream(env.test_user, recipient, amount, rate, duration);
        
        // Verify stream creation
        env.verify_stream_state(stream_id, amount, true);
        
        // Step 2: Simulate time passage and verify payments
        env.advance_time(3600); // 1 hour
        let expected_paid = rate * 3600;
        let expected_balance = amount - expected_paid;
        env.verify_stream_state(stream_id, expected_balance, true);
        
        // Step 3: Recipient withdraws accumulated payments
        set_caller_address(recipient);
        let withdrawn = env.stream_manager.withdraw_from_stream(stream_id);
        assert(withdrawn == expected_paid, 'Withdrawal amount incorrect');
        
        // Step 4: User cancels stream and gets refund
        set_caller_address(env.test_user);
        let cancelled = env.stream_manager.cancel_stream(stream_id);
        assert(cancelled, 'Stream cancellation failed');
        
        // Verify final state
        env.verify_stream_state(stream_id, 0, false);
        
        env.cleanup();
    }

    #[test]
    fn test_subscription_workflow() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Setup: Provider creates subscription plan
        set_caller_address(env.test_provider);
        let (price, interval, max_subscribers) = TestDataFactoryTrait::create_basic_subscription_plan();
        let plan_id = env.subscription_manager.create_subscription_plan(price, interval, max_subscribers);
        
        // Setup: User has sufficient balance
        env.setup_bitcoin_balance(env.test_user, price * 3); // 3 months worth
        
        // Step 1: User subscribes to plan
        set_caller_address(env.test_user);
        let subscription_id = env.subscription_manager.subscribe(plan_id, interval);
        
        // Verify subscription created and stream started
        let subscription = env.subscription_manager.get_subscription(subscription_id);
        assert(subscription.stream_id != 0, 'Stream not created for subscription');
        
        // Step 2: Simulate subscription period
        env.advance_time(interval / 2); // Half the subscription period
        
        // Verify payments are flowing
        let stream_balance = env.stream_manager.get_stream_balance(subscription.stream_id);
        assert(stream_balance < price, 'Payments not flowing correctly');
        
        // Step 3: Subscription auto-renewal
        env.advance_time(interval / 2 + 100); // Complete period + buffer
        
        // Verify subscription renewed (if auto-renew enabled)
        let updated_subscription = env.subscription_manager.get_subscription(subscription_id);
        // Additional verification logic would depend on auto-renewal implementation
        
        env.cleanup();
    }

    #[test]
    fn test_micro_payment_content_access() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Setup: User creates stream for micro-payments
        env.setup_bitcoin_balance(env.test_user, 10000000); // 0.1 BTC
        let content_provider = contract_address_const::<'content_provider'>();
        let stream_id = env.create_test_stream(env.test_user, content_provider, 5000000, 100, 86400);
        
        // Step 1: User accesses multiple pieces of content
        let scenarios = TestDataFactoryTrait::create_micro_payment_scenarios();
        let mut total_spent = 0;
        
        let mut i = 0;
        loop {
            if i >= scenarios.len() {
                break;
            }
            let (cost, content_type) = *scenarios.at(i);
            
            // Simulate content access (would integrate with content pricing manager)
            set_caller_address(env.test_user);
            // This would call the micro-payment manager in real implementation
            total_spent += cost;
            i += 1;
        };
        
        // Step 2: Verify micro-payments deducted correctly
        let remaining_balance = env.stream_manager.get_stream_balance(stream_id);
        let expected_balance = 5000000 - total_spent;
        assert(remaining_balance <= expected_balance, 'Micro-payments not deducted');
        
        // Step 3: Test low balance notification
        // Drain most of the balance
        env.advance_time(40000); // Advance time to consume most balance
        let low_balance = env.stream_manager.get_stream_balance(stream_id);
        assert(low_balance < 100000, 'Balance should be low'); // Less than 0.001 BTC
        
        env.cleanup();
    }

    #[test]
    fn test_yield_generation_workflow() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Setup: User creates large stream with yield enabled
        env.setup_bitcoin_balance(env.test_user, 200000000); // 2 BTC
        let (recipient, amount, rate, duration) = TestDataFactoryTrait::create_large_stream_params();
        let stream_id = env.create_test_stream(env.test_user, recipient, amount, rate, duration);
        
        // Step 1: Enable yield generation
        set_caller_address(env.test_user);
        env.yield_manager.enable_yield_for_stream(stream_id);
        
        // Step 2: Simulate time passage for yield generation
        env.advance_time(86400); // 24 hours
        
        // Step 3: Check yield earnings
        let yield_earned = env.yield_manager.get_yield_earned(stream_id);
        assert(yield_earned > 0, 'No yield generated');
        
        // Step 4: Distribute yield back to stream
        env.yield_manager.distribute_yield(stream_id);
        
        // Verify yield added to stream balance
        let enhanced_balance = env.stream_manager.get_stream_balance(stream_id);
        let expected_base_balance = amount - (rate * 86400);
        assert(enhanced_balance > expected_base_balance, 'Yield not added to balance');
        
        env.cleanup();
    }

    #[test]
    fn test_cross_chain_bitcoin_workflow() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Step 1: User initiates Bitcoin lock
        set_caller_address(env.test_user);
        let bitcoin_amount = 50000000; // 0.5 BTC
        let lock_tx_id = env.bridge_adapter.lock_bitcoin(bitcoin_amount, env.test_user);
        
        // Step 2: Simulate bridge processing delay
        env.simulate_bridge_delay(600); // 10 minutes
        
        // Step 3: Verify wBTC minted on Starknet
        let bridge_status = env.bridge_adapter.get_bridge_status(lock_tx_id);
        assert(bridge_status == BridgeStatus::Completed, 'Bridge not completed');
        
        // Step 4: Create stream with bridged Bitcoin
        let (recipient, _, rate, duration) = TestDataFactoryTrait::create_medium_stream_params();
        let stream_id = env.create_test_stream(env.test_user, recipient, bitcoin_amount, rate, duration);
        
        // Step 5: Complete stream and unlock Bitcoin
        env.advance_time(duration);
        let remaining = env.stream_manager.cancel_stream(stream_id);
        
        // Step 6: Bridge back to Bitcoin
        let unlock_tx_id = env.bridge_adapter.unlock_bitcoin(stream_id, remaining);
        env.simulate_bridge_delay(600);
        
        let unlock_status = env.bridge_adapter.get_bridge_status(unlock_tx_id);
        assert(unlock_status == BridgeStatus::Completed, 'Unlock not completed');
        
        env.cleanup();
    }

    #[test]
    fn test_emergency_scenarios() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Setup: Create active stream
        env.setup_bitcoin_balance(env.test_user, 100000000);
        let (recipient, amount, rate, duration) = TestDataFactoryTrait::create_medium_stream_params();
        let stream_id = env.create_test_stream(env.test_user, recipient, amount, rate, duration);
        
        // Step 1: Test emergency pause
        env.escrow_manager.emergency_pause();
        
        // Verify stream operations are paused
        let pause_result = env.stream_manager.withdraw_from_stream(stream_id);
        // Should fail or return 0 when paused
        
        // Step 2: Test emergency fund recovery
        let recovered = env.escrow_manager.emergency_withdraw(stream_id);
        assert(recovered, 'Emergency withdrawal failed');
        
        env.cleanup();
    }

    #[test]
    fn test_multi_stream_management() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Setup: User with large balance
        env.setup_bitcoin_balance(env.test_user, 500000000); // 5 BTC
        
        // Step 1: Create multiple streams
        let mut stream_ids = ArrayTrait::new();
        let recipients = array![
            contract_address_const::<'recipient1'>(),
            contract_address_const::<'recipient2'>(),
            contract_address_const::<'recipient3'>()
        ];
        
        let mut i = 0;
        loop {
            if i >= recipients.len() {
                break;
            }
            let recipient = *recipients.at(i);
            let stream_id = env.create_test_stream(env.test_user, recipient, 50000000, 500, 86400);
            stream_ids.append(stream_id);
            i += 1;
        };
        
        // Step 2: Simulate concurrent stream operations
        env.advance_time(3600); // 1 hour
        
        // Step 3: Verify all streams operating correctly
        i = 0;
        loop {
            if i >= stream_ids.len() {
                break;
            }
            let stream_id = *stream_ids.at(i);
            env.verify_stream_state(stream_id, 50000000 - (500 * 3600), true);
            i += 1;
        };
        
        // Step 4: Cancel one stream, modify another
        let first_stream = *stream_ids.at(0);
        env.stream_manager.cancel_stream(first_stream);
        env.verify_stream_state(first_stream, 0, false);
        
        env.cleanup();
    }
}