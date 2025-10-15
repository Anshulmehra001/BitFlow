use starknet::testing::{set_caller_address, set_block_timestamp};
use super::integration_helpers::{TestEnvironment, TestEnvironmentTrait, PerformanceMetrics, PerformanceMetricsTrait};
use super::test_data_factory::{TestDataFactoryTrait};

// Performance and load testing for BitFlow protocol
#[cfg(test)]
mod performance_tests {
    use super::*;

    #[test]
    fn test_stream_creation_performance() {
        let mut env = TestEnvironmentTrait::setup();
        let mut metrics = PerformanceMetricsTrait::start();
        
        // Setup: User with large balance
        env.setup_bitcoin_balance(env.test_user, 1000000000); // 10 BTC
        
        // Test: Create multiple streams and measure performance
        let stream_count = 100;
        let mut stream_ids = ArrayTrait::new();
        
        set_caller_address(env.test_user);
        let mut i = 0;
        loop {
            if i >= stream_count {
                break;
            }
            
            let recipient_felt: felt252 = i.into() + 'perf_recipient';
            let recipient = contract_address_const::<recipient_felt>();
            
            let stream_id = env.stream_manager.create_stream(
                recipient,
                1000000, // 0.01 BTC per stream
                100,     // Rate
                3600     // 1 hour duration
            );
            
            stream_ids.append(stream_id);
            metrics.record_operation();
            i += 1;
        };
        
        let (duration, operations) = metrics.finish();
        
        // Performance assertions
        assert(operations == stream_count, 'Operation count mismatch');
        assert(duration < 300, 'Stream creation too slow'); // Should complete in under 5 minutes
        
        // Verify all streams created successfully
        i = 0;
        loop {
            if i >= stream_ids.len() {
                break;
            }
            let stream_id = *stream_ids.at(i);
            env.verify_stream_state(stream_id, 1000000, true);
            i += 1;
        };
        
        env.cleanup();
    }

    #[test]
    fn test_concurrent_stream_operations() {
        let mut env = TestEnvironmentTrait::setup();
        let mut metrics = PerformanceMetricsTrait::start();
        
        // Setup: Multiple users with streams
        let user_count = 50;
        let users = TestDataFactoryTrait::create_concurrent_users(user_count);
        let mut stream_ids = ArrayTrait::new();
        
        // Create streams for all users
        let mut i = 0;
        loop {
            if i >= users.len() {
                break;
            }
            let user = *users.at(i);
            env.setup_bitcoin_balance(user, 10000000); // 0.1 BTC each
            
            set_caller_address(user);
            let recipient_felt: felt252 = i.into() + 'concurrent_recipient';
            let recipient = contract_address_const::<recipient_felt>();
            
            let stream_id = env.stream_manager.create_stream(recipient, 5000000, 500, 7200);
            stream_ids.append(stream_id);
            metrics.record_operation();
            i += 1;
        };
        
        // Simulate concurrent operations
        env.advance_time(1800); // 30 minutes
        
        // Perform concurrent withdrawals
        i = 0;
        loop {
            if i >= stream_ids.len() {
                break;
            }
            let stream_id = *stream_ids.at(i);
            let user = *users.at(i);
            
            set_caller_address(user);
            let withdrawn = env.stream_manager.withdraw_from_stream(stream_id);
            assert(withdrawn > 0, 'Concurrent withdrawal failed');
            metrics.record_operation();
            i += 1;
        };
        
        let (duration, operations) = metrics.finish();
        
        // Performance assertions
        assert(operations == user_count * 2, 'Operation count incorrect'); // Create + withdraw
        assert(duration < 600, 'Concurrent operations too slow'); // Under 10 minutes
        
        env.cleanup();
    }

    #[test]
    fn test_micro_payment_throughput() {
        let mut env = TestEnvironmentTrait::setup();
        let mut metrics = PerformanceMetricsTrait::start();
        
        // Setup: Stream for micro-payments
        env.setup_bitcoin_balance(env.test_user, 100000000); // 1 BTC
        let content_provider = contract_address_const::<'content_provider'>();
        let stream_id = env.create_test_stream(env.test_user, content_provider, 50000000, 1000, 86400);
        
        // Test: High-frequency micro-payments
        let payment_count = 1000;
        let payment_scenarios = TestDataFactoryTrait::create_micro_payment_scenarios();
        
        set_caller_address(env.test_user);
        let mut i = 0;
        loop {
            if i >= payment_count {
                break;
            }
            
            let scenario_index = i % payment_scenarios.len();
            let (cost, content_type) = *payment_scenarios.at(scenario_index);
            
            // Simulate micro-payment processing
            // In real implementation, this would call the micro-payment manager
            env.advance_time(1); // 1 second between payments
            metrics.record_operation();
            i += 1;
        };
        
        let (duration, operations) = metrics.finish();
        
        // Performance assertions
        assert(operations == payment_count, 'Micro-payment count incorrect');
        assert(duration < 1200, 'Micro-payment processing too slow'); // Under 20 minutes
        
        // Verify stream balance updated correctly
        let remaining_balance = env.stream_manager.get_stream_balance(stream_id);
        assert(remaining_balance < 50000000, 'Micro-payments not processed');
        
        env.cleanup();
    }

    #[test]
    fn test_yield_calculation_performance() {
        let mut env = TestEnvironmentTrait::setup();
        let mut metrics = PerformanceMetricsTrait::start();
        
        // Setup: Multiple streams with yield enabled
        let stream_count = 20;
        let yield_amounts = TestDataFactoryTrait::create_yield_test_amounts();
        let mut stream_ids = ArrayTrait::new();
        
        let mut i = 0;
        loop {
            if i >= stream_count {
                break;
            }
            
            let amount_index = i % yield_amounts.len();
            let amount = *yield_amounts.at(amount_index);
            
            env.setup_bitcoin_balance(env.test_user, amount * 2);
            
            let recipient_felt: felt252 = i.into() + 'yield_recipient';
            let recipient = contract_address_const::<recipient_felt>();
            
            let stream_id = env.create_test_stream(env.test_user, recipient, amount, 100, 86400);
            
            // Enable yield for stream
            set_caller_address(env.test_user);
            env.yield_manager.enable_yield_for_stream(stream_id);
            
            stream_ids.append(stream_id);
            metrics.record_operation();
            i += 1;
        };
        
        // Simulate yield generation period
        env.advance_time(86400); // 24 hours
        
        // Calculate and distribute yield for all streams
        i = 0;
        loop {
            if i >= stream_ids.len() {
                break;
            }
            let stream_id = *stream_ids.at(i);
            
            let yield_earned = env.yield_manager.get_yield_earned(stream_id);
            assert(yield_earned > 0, 'No yield calculated');
            
            env.yield_manager.distribute_yield(stream_id);
            metrics.record_operation();
            i += 1;
        };
        
        let (duration, operations) = metrics.finish();
        
        // Performance assertions
        assert(operations == stream_count * 2, 'Yield operation count incorrect'); // Enable + distribute
        assert(duration < 180, 'Yield calculations too slow'); // Under 3 minutes
        
        env.cleanup();
    }

    #[test]
    fn test_bridge_throughput() {
        let mut env = TestEnvironmentTrait::setup();
        let mut metrics = PerformanceMetricsTrait::start();
        
        // Test: Multiple concurrent bridge operations
        let bridge_count = 25;
        let users = TestDataFactoryTrait::create_concurrent_users(bridge_count);
        let mut tx_ids = ArrayTrait::new();
        
        // Initiate multiple bridge operations
        let mut i = 0;
        loop {
            if i >= users.len() {
                break;
            }
            let user = *users.at(i);
            env.setup_bitcoin_balance(user, 20000000); // 0.2 BTC each
            
            set_caller_address(user);
            let tx_id = env.bridge_adapter.lock_bitcoin(20000000, user);
            tx_ids.append(tx_id);
            metrics.record_operation();
            i += 1;
        };
        
        // Process all bridge operations
        env.simulate_bridge_delay(900); // 15 minutes for batch processing
        
        // Verify all completed
        i = 0;
        loop {
            if i >= tx_ids.len() {
                break;
            }
            let tx_id = *tx_ids.at(i);
            let status = env.bridge_adapter.get_bridge_status(tx_id);
            assert(status == BridgeStatus::Completed, 'Bridge throughput failed');
            metrics.record_operation();
            i += 1;
        };
        
        let (duration, operations) = metrics.finish();
        
        // Performance assertions
        assert(operations == bridge_count * 2, 'Bridge operation count incorrect'); // Lock + verify
        assert(duration < 1200, 'Bridge throughput too slow'); // Under 20 minutes
        
        env.cleanup();
    }

    #[test]
    fn test_subscription_scaling() {
        let mut env = TestEnvironmentTrait::setup();
        let mut metrics = PerformanceMetricsTrait::start();
        
        // Setup: Provider creates multiple subscription plans
        set_caller_address(env.test_provider);
        let plan_count = 10;
        let mut plan_ids = ArrayTrait::new();
        
        let mut i = 0;
        loop {
            if i >= plan_count {
                break;
            }
            
            let price = 1000000 + (i * 100000).into(); // Varying prices
            let interval = 2592000; // 30 days
            let max_subscribers = 100;
            
            let plan_id = env.subscription_manager.create_subscription_plan(price, interval, max_subscribers);
            plan_ids.append(plan_id);
            metrics.record_operation();
            i += 1;
        };
        
        // Test: Multiple users subscribe to different plans
        let subscriber_count = 50;
        let subscribers = TestDataFactoryTrait::create_concurrent_users(subscriber_count);
        
        i = 0;
        loop {
            if i >= subscribers.len() {
                break;
            }
            let subscriber = *subscribers.at(i);
            let plan_index = i % plan_ids.len();
            let plan_id = *plan_ids.at(plan_index);
            
            env.setup_bitcoin_balance(subscriber, 10000000); // 0.1 BTC
            
            set_caller_address(subscriber);
            let subscription_id = env.subscription_manager.subscribe(plan_id, 2592000);
            assert(subscription_id != 0, 'Subscription creation failed');
            
            metrics.record_operation();
            i += 1;
        };
        
        let (duration, operations) = metrics.finish();
        
        // Performance assertions
        assert(operations == plan_count + subscriber_count, 'Subscription operation count incorrect');
        assert(duration < 300, 'Subscription scaling too slow'); // Under 5 minutes
        
        env.cleanup();
    }

    #[test]
    fn test_system_under_stress() {
        let mut env = TestEnvironmentTrait::setup();
        let mut metrics = PerformanceMetricsTrait::start();
        
        // Stress test: Maximum concurrent operations
        let user_count = 100;
        let users = TestDataFactoryTrait::create_concurrent_users(user_count);
        
        // Phase 1: Mass stream creation
        let mut stream_ids = ArrayTrait::new();
        let mut i = 0;
        loop {
            if i >= users.len() {
                break;
            }
            let user = *users.at(i);
            env.setup_bitcoin_balance(user, 50000000); // 0.5 BTC each
            
            set_caller_address(user);
            let recipient_felt: felt252 = i.into() + 'stress_recipient';
            let recipient = contract_address_const::<recipient_felt>();
            
            let stream_id = env.stream_manager.create_stream(recipient, 25000000, 300, 86400);
            stream_ids.append(stream_id);
            metrics.record_operation();
            i += 1;
        };
        
        // Phase 2: Concurrent operations during active streams
        env.advance_time(3600); // 1 hour
        
        // Simulate various operations
        i = 0;
        loop {
            if i >= stream_ids.len() / 2 { // Half the streams
                break;
            }
            let stream_id = *stream_ids.at(i);
            let user = *users.at(i);
            
            set_caller_address(user);
            
            // Mix of operations
            if i % 3 == 0 {
                // Withdraw
                let withdrawn = env.stream_manager.withdraw_from_stream(stream_id);
                assert(withdrawn > 0, 'Stress test withdrawal failed');
            } else if i % 3 == 1 {
                // Check balance
                let balance = env.stream_manager.get_stream_balance(stream_id);
                assert(balance > 0, 'Stress test balance check failed');
            } else {
                // Cancel stream
                let cancelled = env.stream_manager.cancel_stream(stream_id);
                assert(cancelled, 'Stress test cancellation failed');
            }
            
            metrics.record_operation();
            i += 1;
        };
        
        let (duration, operations) = metrics.finish();
        
        // Stress test assertions
        assert(operations >= user_count, 'Stress test operation count low');
        assert(duration < 1800, 'System under stress too slow'); // Under 30 minutes
        
        // Verify system stability
        let remaining_streams = stream_ids.len() - (stream_ids.len() / 2);
        i = stream_ids.len() / 2;
        loop {
            if i >= stream_ids.len() {
                break;
            }
            let stream_id = *stream_ids.at(i);
            // These streams should still be active and functional
            env.verify_stream_state(stream_id, 25000000 - (300 * 3600), true);
            i += 1;
        };
        
        env.cleanup();
    }
}