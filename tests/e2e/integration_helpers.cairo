use starknet::{ContractAddress, contract_address_const};
use starknet::testing::{set_caller_address, set_block_timestamp};
use bitflow::interfaces::stream_manager::{IStreamManagerDispatcher, IStreamManagerDispatcherTrait};
use bitflow::interfaces::escrow_manager::{IEscrowManagerDispatcher, IEscrowManagerDispatcherTrait};
use bitflow::interfaces::bridge_adapter::{IBridgeAdapterDispatcher, IBridgeAdapterDispatcherTrait};
use bitflow::interfaces::yield_manager::{IYieldManagerDispatcher, IYieldManagerDispatcherTrait};
use bitflow::interfaces::subscription_manager::{ISubscriptionManagerDispatcher, ISubscriptionManagerDispatcherTrait};
use bitflow::types::{PaymentStream, Subscription, BridgeStatus};

// Test environment setup and utilities
#[derive(Drop, Clone)]
struct TestEnvironment {
    stream_manager: IStreamManagerDispatcher,
    escrow_manager: IEscrowManagerDispatcher,
    bridge_adapter: IBridgeAdapterDispatcher,
    yield_manager: IYieldManagerDispatcher,
    subscription_manager: ISubscriptionManagerDispatcher,
    test_user: ContractAddress,
    test_recipient: ContractAddress,
    test_provider: ContractAddress,
}

#[generate_trait]
impl TestEnvironmentImpl of TestEnvironmentTrait {
    fn setup() -> TestEnvironment {
        let test_user = contract_address_const::<'test_user'>();
        let test_recipient = contract_address_const::<'test_recipient'>();
        let test_provider = contract_address_const::<'test_provider'>();
        
        // Deploy all contracts (implementation would depend on actual deployment setup)
        let stream_manager = IStreamManagerDispatcher { 
            contract_address: contract_address_const::<'stream_manager'>() 
        };
        let escrow_manager = IEscrowManagerDispatcher { 
            contract_address: contract_address_const::<'escrow_manager'>() 
        };
        let bridge_adapter = IBridgeAdapterDispatcher { 
            contract_address: contract_address_const::<'bridge_adapter'>() 
        };
        let yield_manager = IYieldManagerDispatcher { 
            contract_address: contract_address_const::<'yield_manager'>() 
        };
        let subscription_manager = ISubscriptionManagerDispatcher { 
            contract_address: contract_address_const::<'subscription_manager'>() 
        };

        TestEnvironment {
            stream_manager,
            escrow_manager,
            bridge_adapter,
            yield_manager,
            subscription_manager,
            test_user,
            test_recipient,
            test_provider,
        }
    }

    fn setup_bitcoin_balance(ref self: TestEnvironment, user: ContractAddress, amount: u256) {
        set_caller_address(user);
        // Mock Bitcoin balance setup
        self.bridge_adapter.mock_bitcoin_balance(user, amount);
    }

    fn advance_time(ref self: TestEnvironment, seconds: u64) {
        let current_time = starknet::get_block_timestamp();
        set_block_timestamp(current_time + seconds);
    }

    fn create_test_stream(
        ref self: TestEnvironment,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
        rate: u256,
        duration: u64
    ) -> u256 {
        set_caller_address(sender);
        self.stream_manager.create_stream(recipient, amount, rate, duration)
    }

    fn verify_stream_state(
        ref self: TestEnvironment,
        stream_id: u256,
        expected_balance: u256,
        expected_active: bool
    ) {
        let stream = self.stream_manager.get_stream(stream_id);
        assert(stream.is_active == expected_active, 'Stream active state mismatch');
        
        let balance = self.stream_manager.get_stream_balance(stream_id);
        assert(balance == expected_balance, 'Stream balance mismatch');
    }

    fn simulate_bridge_delay(ref self: TestEnvironment, delay_seconds: u64) {
        // Simulate cross-chain bridge processing time
        self.advance_time(delay_seconds);
        // Update bridge status to completed
        self.bridge_adapter.mock_bridge_completion();
    }

    fn cleanup(ref self: TestEnvironment) {
        // Reset test state
        set_block_timestamp(0);
        set_caller_address(contract_address_const::<0>());
    }
}

// Performance measurement utilities
#[derive(Drop, Clone)]
struct PerformanceMetrics {
    start_time: u64,
    gas_used: u256,
    operations_count: u32,
}

#[generate_trait]
impl PerformanceMetricsImpl of PerformanceMetricsTrait {
    fn start() -> PerformanceMetrics {
        PerformanceMetrics {
            start_time: starknet::get_block_timestamp(),
            gas_used: 0,
            operations_count: 0,
        }
    }

    fn record_operation(ref self: PerformanceMetrics) {
        self.operations_count += 1;
    }

    fn finish(ref self: PerformanceMetrics) -> (u64, u32) {
        let duration = starknet::get_block_timestamp() - self.start_time;
        (duration, self.operations_count)
    }
}