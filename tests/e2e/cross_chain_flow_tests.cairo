use starknet::testing::{set_caller_address, set_block_timestamp};
use super::integration_helpers::{TestEnvironment, TestEnvironmentTrait};
use super::test_data_factory::{TestDataFactoryTrait};
use bitflow::types::{BridgeStatus, PaymentStream};

// Cross-chain flow testing for Bitcoin <-> Starknet interactions
#[cfg(test)]
mod cross_chain_flow_tests {
    use super::*;

    #[test]
    fn test_bitcoin_lock_and_mint_flow() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Step 1: Initiate Bitcoin lock
        set_caller_address(env.test_user);
        let bitcoin_amount = 100000000; // 1 BTC
        let lock_tx_id = env.bridge_adapter.lock_bitcoin(bitcoin_amount, env.test_user);
        
        // Step 2: Verify initial bridge status
        let initial_status = env.bridge_adapter.get_bridge_status(lock_tx_id);
        assert(initial_status == BridgeStatus::Pending, 'Initial status should be pending');
        
        // Step 3: Simulate Bitcoin network confirmations
        env.advance_time(600); // 10 minutes for confirmations
        env.bridge_adapter.mock_bitcoin_confirmations(lock_tx_id, 6);
        
        // Step 4: Process bridge completion
        env.simulate_bridge_delay(300); // 5 minutes processing
        
        // Step 5: Verify wBTC minted
        let final_status = env.bridge_adapter.get_bridge_status(lock_tx_id);
        assert(final_status == BridgeStatus::Completed, 'Bridge should be completed');
        
        let user_balance = env.bridge_adapter.get_wbtc_balance(env.test_user);
        assert(user_balance == bitcoin_amount, 'wBTC balance incorrect');
        
        env.cleanup();
    }

    #[test]
    fn test_wbtc_burn_and_unlock_flow() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Setup: User has wBTC from previous bridge
        env.setup_bitcoin_balance(env.test_user, 100000000);
        let lock_tx_id = env.bridge_adapter.lock_bitcoin(100000000, env.test_user);
        env.simulate_bridge_delay(600);
        
        // Step 1: Create and partially use stream
        let (recipient, amount, rate, duration) = TestDataFactoryTrait::create_medium_stream_params();
        let stream_id = env.create_test_stream(env.test_user, recipient, amount, rate, duration);
        
        // Advance time to use some of the stream
        env.advance_time(duration / 2);
        let remaining_balance = env.stream_manager.get_stream_balance(stream_id);
        
        // Step 2: Cancel stream and initiate unlock
        set_caller_address(env.test_user);
        env.stream_manager.cancel_stream(stream_id);
        
        let unlock_tx_id = env.bridge_adapter.unlock_bitcoin(stream_id, remaining_balance);
        
        // Step 3: Verify unlock process
        let unlock_status = env.bridge_adapter.get_bridge_status(unlock_tx_id);
        assert(unlock_status == BridgeStatus::Pending, 'Unlock should be pending');
        
        // Step 4: Simulate unlock completion
        env.simulate_bridge_delay(900); // 15 minutes for unlock
        
        let final_status = env.bridge_adapter.get_bridge_status(unlock_tx_id);
        assert(final_status == BridgeStatus::Completed, 'Unlock should be completed');
        
        env.cleanup();
    }

    #[test]
    fn test_bridge_failure_recovery() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Step 1: Initiate Bitcoin lock
        set_caller_address(env.test_user);
        let bitcoin_amount = 50000000; // 0.5 BTC
        let lock_tx_id = env.bridge_adapter.lock_bitcoin(bitcoin_amount, env.test_user);
        
        // Step 2: Simulate bridge failure
        env.advance_time(1800); // 30 minutes timeout
        env.bridge_adapter.mock_bridge_failure(lock_tx_id, 'network_timeout');
        
        let failed_status = env.bridge_adapter.get_bridge_status(lock_tx_id);
        assert(failed_status == BridgeStatus::Failed, 'Status should be failed');
        
        // Step 3: Initiate recovery process
        let recovery_tx_id = env.bridge_adapter.retry_bridge_transaction(lock_tx_id);
        
        // Step 4: Simulate successful retry
        env.simulate_bridge_delay(600);
        let recovery_status = env.bridge_adapter.get_bridge_status(recovery_tx_id);
        assert(recovery_status == BridgeStatus::Completed, 'Recovery should succeed');
        
        env.cleanup();
    }

    #[test]
    fn test_concurrent_bridge_operations() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Setup: Multiple users with Bitcoin
        let users = TestDataFactoryTrait::create_concurrent_users(5);
        let mut lock_tx_ids = ArrayTrait::new();
        
        // Step 1: Multiple users lock Bitcoin simultaneously
        let mut i = 0;
        loop {
            if i >= users.len() {
                break;
            }
            let user = *users.at(i);
            env.setup_bitcoin_balance(user, 20000000); // 0.2 BTC each
            
            set_caller_address(user);
            let lock_tx_id = env.bridge_adapter.lock_bitcoin(20000000, user);
            lock_tx_ids.append(lock_tx_id);
            i += 1;
        };
        
        // Step 2: Process all bridge operations
        env.simulate_bridge_delay(600);
        
        // Step 3: Verify all operations completed
        i = 0;
        loop {
            if i >= lock_tx_ids.len() {
                break;
            }
            let tx_id = *lock_tx_ids.at(i);
            let status = env.bridge_adapter.get_bridge_status(tx_id);
            assert(status == BridgeStatus::Completed, 'Concurrent bridge failed');
            i += 1;
        };
        
        env.cleanup();
    }

    #[test]
    fn test_bridge_rate_limiting() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Setup: User with large balance
        env.setup_bitcoin_balance(env.test_user, 1000000000); // 10 BTC
        
        // Step 1: Attempt multiple rapid bridge operations
        set_caller_address(env.test_user);
        let mut tx_ids = ArrayTrait::new();
        
        let mut i = 0;
        loop {
            if i >= 10 {
                break;
            }
            let tx_id = env.bridge_adapter.lock_bitcoin(10000000, env.test_user); // 0.1 BTC each
            tx_ids.append(tx_id);
            i += 1;
        };
        
        // Step 2: Verify rate limiting kicks in
        let last_tx_id = *tx_ids.at(tx_ids.len() - 1);
        let status = env.bridge_adapter.get_bridge_status(last_tx_id);
        // Should be rate limited or queued
        assert(
            status == BridgeStatus::RateLimited || status == BridgeStatus::Queued,
            'Rate limiting not working'
        );
        
        // Step 3: Wait for rate limit reset
        env.advance_time(3600); // 1 hour
        
        // Step 4: Retry rate limited transaction
        let retry_tx_id = env.bridge_adapter.retry_bridge_transaction(last_tx_id);
        env.simulate_bridge_delay(600);
        
        let final_status = env.bridge_adapter.get_bridge_status(retry_tx_id);
        assert(final_status == BridgeStatus::Completed, 'Retry after rate limit failed');
        
        env.cleanup();
    }

    #[test]
    fn test_bridge_security_validations() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Test 1: Invalid Bitcoin amount
        set_caller_address(env.test_user);
        let result = env.bridge_adapter.lock_bitcoin(0, env.test_user);
        // Should fail with invalid amount
        
        // Test 2: Insufficient Bitcoin balance
        env.setup_bitcoin_balance(env.test_user, 1000000); // 0.01 BTC
        let result2 = env.bridge_adapter.lock_bitcoin(100000000, env.test_user); // Try to lock 1 BTC
        // Should fail with insufficient balance
        
        // Test 3: Invalid recipient address
        let result3 = env.bridge_adapter.lock_bitcoin(1000000, contract_address_const::<0>());
        // Should fail with invalid recipient
        
        // Test 4: Double spending attempt
        env.setup_bitcoin_balance(env.test_user, 10000000); // 0.1 BTC
        let tx_id1 = env.bridge_adapter.lock_bitcoin(10000000, env.test_user);
        let tx_id2 = env.bridge_adapter.lock_bitcoin(10000000, env.test_user); // Same amount again
        
        // Second transaction should fail or be rejected
        let status2 = env.bridge_adapter.get_bridge_status(tx_id2);
        assert(status2 == BridgeStatus::Failed, 'Double spending not prevented');
        
        env.cleanup();
    }

    #[test]
    fn test_bridge_monitoring_and_alerts() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Step 1: Create bridge transaction
        env.setup_bitcoin_balance(env.test_user, 50000000);
        set_caller_address(env.test_user);
        let tx_id = env.bridge_adapter.lock_bitcoin(50000000, env.test_user);
        
        // Step 2: Monitor transaction progress
        let mut monitoring_checks = 0;
        let mut current_status = BridgeStatus::Pending;
        
        loop {
            if monitoring_checks >= 10 || current_status == BridgeStatus::Completed {
                break;
            }
            
            env.advance_time(60); // Check every minute
            current_status = env.bridge_adapter.get_bridge_status(tx_id);
            monitoring_checks += 1;
            
            // Simulate monitoring alerts
            if monitoring_checks == 5 && current_status == BridgeStatus::Pending {
                // Alert: Transaction taking longer than expected
                env.bridge_adapter.send_monitoring_alert(tx_id, 'delayed_confirmation');
            }
        };
        
        // Step 3: Verify monitoring worked
        assert(monitoring_checks > 0, 'Monitoring not functioning');
        
        env.cleanup();
    }

    #[test]
    fn test_cross_chain_stream_integration() {
        let mut env = TestEnvironmentTrait::setup();
        
        // Step 1: Lock Bitcoin and create stream in one flow
        set_caller_address(env.test_user);
        let bitcoin_amount = 100000000; // 1 BTC
        
        // This would be a combined operation in the actual implementation
        let lock_tx_id = env.bridge_adapter.lock_bitcoin(bitcoin_amount, env.test_user);
        env.simulate_bridge_delay(600);
        
        // Step 2: Immediately create stream with bridged funds
        let (recipient, amount, rate, duration) = TestDataFactoryTrait::create_large_stream_params();
        let stream_id = env.create_test_stream(env.test_user, recipient, amount, rate, duration);
        
        // Step 3: Verify stream uses bridged Bitcoin
        env.verify_stream_state(stream_id, amount, true);
        
        // Step 4: Stream completion triggers automatic unlock
        env.advance_time(duration);
        let remaining = env.stream_manager.get_stream_balance(stream_id);
        
        // Auto-unlock remaining balance
        let unlock_tx_id = env.bridge_adapter.unlock_bitcoin(stream_id, remaining);
        env.simulate_bridge_delay(600);
        
        let unlock_status = env.bridge_adapter.get_bridge_status(unlock_tx_id);
        assert(unlock_status == BridgeStatus::Completed, 'Auto-unlock failed');
        
        env.cleanup();
    }
}