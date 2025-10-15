use starknet::{ContractAddress, contract_address_const};
use bitflow::types::{PaymentStream, Subscription, YieldPosition};

// Factory for creating test data with realistic scenarios
#[generate_trait]
impl TestDataFactoryImpl of TestDataFactoryTrait {
    // Stream test data
    fn create_small_stream_params() -> (ContractAddress, u256, u256, u64) {
        let recipient = contract_address_const::<'small_recipient'>();
        let amount = 1000000; // 0.01 BTC in satoshis
        let rate = 115; // ~0.0001 BTC per second (about $0.006/sec at $60k BTC)
        let duration = 8640; // 2.4 hours
        (recipient, amount, rate, duration)
    }

    fn create_medium_stream_params() -> (ContractAddress, u256, u256, u64) {
        let recipient = contract_address_const::<'medium_recipient'>();
        let amount = 10000000; // 0.1 BTC
        let rate = 1157; // ~0.001 BTC per second
        let duration = 86400; // 24 hours
        (recipient, amount, rate, duration)
    }

    fn create_large_stream_params() -> (ContractAddress, u256, u256, u64) {
        let recipient = contract_address_const::<'large_recipient'>();
        let amount = 100000000; // 1 BTC
        let rate = 11574; // ~0.01 BTC per second
        let duration = 864000; // 10 days
        (recipient, amount, rate, duration)
    }

    // Subscription test data
    fn create_basic_subscription_plan() -> (u256, u64, u32) {
        let price = 500000; // 0.005 BTC monthly
        let interval = 2592000; // 30 days in seconds
        let max_subscribers = 1000;
        (price, interval, max_subscribers)
    }

    fn create_premium_subscription_plan() -> (u256, u64, u32) {
        let price = 2000000; // 0.02 BTC monthly
        let interval = 2592000; // 30 days
        let max_subscribers = 100;
        (price, interval, max_subscribers)
    }

    // Micro-payment test data
    fn create_micro_payment_scenarios() -> Array<(u256, felt252)> {
        let mut scenarios = ArrayTrait::new();
        scenarios.append((100, 'article_read')); // $0.006 per article
        scenarios.append((50, 'api_call')); // $0.003 per API call
        scenarios.append((25, 'video_minute')); // $0.0015 per minute
        scenarios.append((10, 'image_view')); // $0.0006 per image
        scenarios
    }

    // Load testing data
    fn create_concurrent_users(count: u32) -> Array<ContractAddress> {
        let mut users = ArrayTrait::new();
        let mut i = 0;
        loop {
            if i >= count {
                break;
            }
            let user_felt: felt252 = i.into() + 'user_base';
            users.append(contract_address_const::<user_felt>());
            i += 1;
        };
        users
    }

    fn create_stress_test_streams(user_count: u32) -> Array<(ContractAddress, u256, u256, u64)> {
        let mut streams = ArrayTrait::new();
        let mut i = 0;
        loop {
            if i >= user_count {
                break;
            }
            let recipient_felt: felt252 = i.into() + 'recipient_base';
            let recipient = contract_address_const::<recipient_felt>();
            
            // Vary stream parameters for realistic load
            let amount = 1000000 + (i * 100000).into(); // Varying amounts
            let rate = 100 + (i * 10).into(); // Varying rates
            let duration = 3600 + (i * 60).into(); // Varying durations
            
            streams.append((recipient, amount, rate, duration));
            i += 1;
        };
        streams
    }

    // Cross-chain test scenarios
    fn create_bridge_failure_scenarios() -> Array<felt252> {
        let mut scenarios = ArrayTrait::new();
        scenarios.append('network_congestion');
        scenarios.append('insufficient_confirmations');
        scenarios.append('bridge_maintenance');
        scenarios.append('rate_limit_exceeded');
        scenarios.append('invalid_bitcoin_tx');
        scenarios
    }

    // Yield testing data
    fn create_yield_test_amounts() -> Array<u256> {
        let mut amounts = ArrayTrait::new();
        amounts.append(1000000); // 0.01 BTC
        amounts.append(5000000); // 0.05 BTC
        amounts.append(10000000); // 0.1 BTC
        amounts.append(50000000); // 0.5 BTC
        amounts.append(100000000); // 1 BTC
        amounts
    }

    // Error scenario data
    fn create_error_scenarios() -> Array<felt252> {
        let mut scenarios = ArrayTrait::new();
        scenarios.append('insufficient_balance');
        scenarios.append('stream_expired');
        scenarios.append('unauthorized_access');
        scenarios.append('contract_paused');
        scenarios.append('invalid_parameters');
        scenarios.append('bridge_timeout');
        scenarios.append('yield_protocol_failure');
        scenarios
    }
}