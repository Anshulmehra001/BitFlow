use starknet::testing::{set_caller_address, set_block_timestamp};
use super::audit_helpers::{SecurityTestEnvironment, SecurityTestEnvironmentTrait};
use bitflow::types::{PaymentStream, Subscription};

// Access control and permission validation tests
#[cfg(test)]
mod access_control_tests {
    use super::*;

    #[test]
    fn test_admin_role_management() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Test 1: Only admin can set emergency admin
        set_caller_address(env.admin);
        let admin_set_result = env.escrow_manager.set_emergency_admin(env.legitimate_user);
        assert(admin_set_result, 'Admin failed to set emergency admin');
        
        // Test 2: Non-admin cannot set emergency admin
        set_caller_address(env.attacker);
        let non_admin_result = env.escrow_manager.set_emergency_admin(env.attacker);
        assert(!non_admin_result, 'Non-admin set emergency admin');
        
        // Test 3: Admin can transfer admin role
        set_caller_address(env.admin);
        let transfer_result = env.escrow_manager.transfer_admin_role(env.legitimate_user);
        assert(transfer_result, 'Admin failed to transfer role');
        
        // Test 4: Old admin loses privileges
        let old_admin_result = env.escrow_manager.set_emergency_admin(env.admin);
        assert(!old_admin_result, 'Old admin retained privileges');
        
        // Test 5: New admin has privileges
        set_caller_address(env.legitimate_user);
        let new_admin_result = env.escrow_manager.set_emergency_admin(env.admin);
        assert(new_admin_result, 'New admin lacks privileges');
        
        env.cleanup();
    }

    #[test]
    fn test_stream_ownership_validation() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Setup: Create stream as victim
        set_caller_address(env.victim);
        env.setup_user_balance(env.victim, 50000000);
        
        let stream_id = env.stream_manager.create_stream(
            env.legitimate_user,
            25000000,
            2500,
            3600
        );
        
        env.advance_time(1800); // 30 minutes
        
        // Test 1: Only stream sender can cancel
        set_caller_address(env.attacker);
        let unauthorized_cancel = env.stream_manager.cancel_stream(stream_id);
        assert(!unauthorized_cancel, 'Unauthorized stream cancellation succeeded');
        
        // Test 2: Only stream recipient can withdraw
        let unauthorized_withdraw = env.stream_manager.withdraw_from_stream(stream_id);
        assert(unauthorized_withdraw == 0, 'Unauthorized withdrawal succeeded');
        
        // Test 3: Stream sender can cancel
        set_caller_address(env.victim);
        let authorized_cancel = env.stream_manager.cancel_stream(stream_id);
        assert(authorized_cancel, 'Authorized cancellation failed');
        
        // Test 4: Create new stream for recipient withdrawal test
        let stream_id2 = env.stream_manager.create_stream(
            env.legitimate_user,
            25000000,
            2500,
            3600
        );
        
        env.advance_time(1800);
        
        // Test 5: Stream recipient can withdraw
        set_caller_address(env.legitimate_user);
        let authorized_withdraw = env.stream_manager.withdraw_from_stream(stream_id2);
        assert(authorized_withdraw > 0, 'Authorized withdrawal failed');
        
        env.cleanup();
    }

    #[test]
    fn test_subscription_access_control() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Setup: Provider creates subscription plan
        set_caller_address(env.legitimate_user); // Provider
        let plan_id = env.subscription_manager.create_subscription_plan(
            5000000, // 0.05 BTC monthly
            2592000, // 30 days
            100      // Max subscribers
        );
        
        // Test 1: Only plan creator can modify plan
        set_caller_address(env.attacker);
        let unauthorized_modify = env.subscription_manager.modify_subscription_plan(
            plan_id,
            10000000, // Double the price
            2592000,
            50
        );
        assert(!unauthorized_modify, 'Unauthorized plan modification succeeded');
        
        // Test 2: Anyone can subscribe to public plan
        env.setup_user_balance(env.victim, 20000000);
        set_caller_address(env.victim);
        let subscription_id = env.subscription_manager.subscribe(plan_id, 2592000);
        assert(subscription_id != 0, 'Public subscription failed');
        
        // Test 3: Only subscriber can cancel their subscription
        set_caller_address(env.attacker);
        let unauthorized_cancel = env.subscription_manager.cancel_subscription(subscription_id);
        assert(!unauthorized_cancel, 'Unauthorized subscription cancellation succeeded');
        
        // Test 4: Subscriber can cancel their own subscription
        set_caller_address(env.victim);
        let authorized_cancel = env.subscription_manager.cancel_subscription(subscription_id);
        assert(authorized_cancel, 'Authorized subscription cancellation failed');
        
        // Test 5: Plan creator can disable plan
        set_caller_address(env.legitimate_user);
        let disable_result = env.subscription_manager.disable_subscription_plan(plan_id);
        assert(disable_result, 'Plan creator failed to disable plan');
        
        // Test 6: Cannot subscribe to disabled plan
        set_caller_address(env.victim);
        let disabled_subscription = env.subscription_manager.subscribe(plan_id, 2592000);
        assert(disabled_subscription == 0, 'Subscription to disabled plan succeeded');
        
        env.cleanup();
    }

    #[test]
    fn test_emergency_functions_access() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Test 1: Only admin can trigger emergency pause
        set_caller_address(env.attacker);
        let unauthorized_pause = env.escrow_manager.emergency_pause();
        assert(!unauthorized_pause, 'Unauthorized emergency pause succeeded');
        
        // Test 2: Admin can trigger emergency pause
        set_caller_address(env.admin);
        let authorized_pause = env.escrow_manager.emergency_pause();
        assert(authorized_pause, 'Authorized emergency pause failed');
        
        // Test 3: Emergency pause affects all operations
        set_caller_address(env.victim);
        env.setup_user_balance(env.victim, 50000000);
        
        let paused_stream = env.stream_manager.create_stream(
            env.legitimate_user,
            25000000,
            2500,
            3600
        );
        assert(paused_stream == 0, 'Stream creation succeeded during pause');
        
        // Test 4: Only admin can unpause
        set_caller_address(env.attacker);
        let unauthorized_unpause = env.escrow_manager.emergency_unpause();
        assert(!unauthorized_unpause, 'Unauthorized unpause succeeded');
        
        // Test 5: Admin can unpause
        set_caller_address(env.admin);
        let authorized_unpause = env.escrow_manager.emergency_unpause();
        assert(authorized_unpause, 'Authorized unpause failed');
        
        // Test 6: Operations resume after unpause
        set_caller_address(env.victim);
        let resumed_stream = env.stream_manager.create_stream(
            env.legitimate_user,
            25000000,
            2500,
            3600
        );
        assert(resumed_stream != 0, 'Stream creation failed after unpause');
        
        env.cleanup();
    }

    #[test]
    fn test_bridge_access_control() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Test 1: Users can lock their own Bitcoin
        set_caller_address(env.victim);
        env.setup_user_balance(env.victim, 100000000);
        
        let lock_tx_id = env.bridge_adapter.lock_bitcoin(50000000, env.victim);
        assert(lock_tx_id != 0, 'User failed to lock own Bitcoin');
        
        // Test 2: Users cannot lock Bitcoin for others without permission
        set_caller_address(env.attacker);
        env.setup_user_balance(env.attacker, 100000000);
        
        let unauthorized_lock = env.bridge_adapter.lock_bitcoin(50000000, env.victim);
        assert(unauthorized_lock == 0, 'Unauthorized Bitcoin lock succeeded');
        
        // Test 3: Only bridge admin can set bridge parameters
        set_caller_address(env.attacker);
        let unauthorized_config = env.bridge_adapter.set_bridge_fee(1000); // 0.1%
        assert(!unauthorized_config, 'Unauthorized bridge config succeeded');
        
        // Test 4: Bridge admin can set parameters
        set_caller_address(env.admin);
        let authorized_config = env.bridge_adapter.set_bridge_fee(500); // 0.05%
        assert(authorized_config, 'Authorized bridge config failed');
        
        // Test 5: Users can unlock their own Bitcoin
        env.simulate_bridge_delay(600); // Complete lock transaction
        
        set_caller_address(env.victim);
        let unlock_tx_id = env.bridge_adapter.unlock_bitcoin(lock_tx_id, 25000000);
        assert(unlock_tx_id != 0, 'User failed to unlock own Bitcoin');
        
        // Test 6: Users cannot unlock others' Bitcoin
        set_caller_address(env.attacker);
        let unauthorized_unlock = env.bridge_adapter.unlock_bitcoin(lock_tx_id, 25000000);
        assert(unauthorized_unlock == 0, 'Unauthorized Bitcoin unlock succeeded');
        
        env.cleanup();
    }

    #[test]
    fn test_yield_management_access() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Setup: Create stream with yield
        set_caller_address(env.victim);
        env.setup_user_balance(env.victim, 100000000);
        
        let stream_id = env.stream_manager.create_stream(
            env.legitimate_user,
            50000000,
            5000,
            7200
        );
        
        // Test 1: Only stream owner can enable yield
        set_caller_address(env.attacker);
        let unauthorized_yield = env.yield_manager.enable_yield_for_stream(stream_id);
        assert(!unauthorized_yield, 'Unauthorized yield enable succeeded');
        
        // Test 2: Stream owner can enable yield
        set_caller_address(env.victim);
        let authorized_yield = env.yield_manager.enable_yield_for_stream(stream_id);
        assert(authorized_yield, 'Authorized yield enable failed');
        
        env.advance_time(3600); // 1 hour for yield generation
        
        // Test 3: Only stream owner can claim yield
        set_caller_address(env.attacker);
        let unauthorized_claim = env.yield_manager.claim_yield(stream_id);
        assert(unauthorized_claim == 0, 'Unauthorized yield claim succeeded');
        
        // Test 4: Stream owner can claim yield
        set_caller_address(env.victim);
        let authorized_claim = env.yield_manager.claim_yield(stream_id);
        assert(authorized_claim > 0, 'Authorized yield claim failed');
        
        // Test 5: Only yield admin can set yield parameters
        set_caller_address(env.attacker);
        let unauthorized_params = env.yield_manager.set_yield_parameters(500, 10000); // 5% APY, 1% fee
        assert(!unauthorized_params, 'Unauthorized yield params succeeded');
        
        // Test 6: Yield admin can set parameters
        set_caller_address(env.admin);
        let authorized_params = env.yield_manager.set_yield_parameters(400, 500); // 4% APY, 0.5% fee
        assert(authorized_params, 'Authorized yield params failed');
        
        env.cleanup();
    }

    #[test]
    fn test_multi_signature_requirements() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Test multi-signature requirements for critical operations
        let multisig_admin1 = contract_address_const::<'multisig_admin1'>();
        let multisig_admin2 = contract_address_const::<'multisig_admin2'>();
        let multisig_admin3 = contract_address_const::<'multisig_admin3'>();
        
        // Setup multi-signature requirement
        set_caller_address(env.admin);
        env.escrow_manager.setup_multisig(
            array![multisig_admin1, multisig_admin2, multisig_admin3],
            2 // Require 2 out of 3 signatures
        );
        
        // Test 1: Single signature insufficient for critical operation
        set_caller_address(multisig_admin1);
        let single_sig_result = env.escrow_manager.emergency_withdraw_all();
        assert(!single_sig_result, 'Single signature succeeded for critical operation');
        
        // Test 2: Two signatures sufficient
        set_caller_address(multisig_admin1);
        let proposal_id = env.escrow_manager.propose_emergency_withdrawal();
        assert(proposal_id != 0, 'Failed to create multisig proposal');
        
        set_caller_address(multisig_admin2);
        let approval_result = env.escrow_manager.approve_proposal(proposal_id);
        assert(approval_result, 'Failed to approve multisig proposal');
        
        // Test 3: Execute with sufficient signatures
        let execution_result = env.escrow_manager.execute_proposal(proposal_id);
        assert(execution_result, 'Failed to execute multisig proposal');
        
        // Test 4: Cannot execute same proposal twice
        let double_execution = env.escrow_manager.execute_proposal(proposal_id);
        assert(!double_execution, 'Double execution of multisig proposal succeeded');
        
        env.cleanup();
    }

    #[test]
    fn test_role_based_permissions() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Define different roles
        let operator = contract_address_const::<'operator'>();
        let auditor = contract_address_const::<'auditor'>();
        let user = contract_address_const::<'user'>();
        
        // Setup roles
        set_caller_address(env.admin);
        env.escrow_manager.assign_role(operator, 'operator');
        env.escrow_manager.assign_role(auditor, 'auditor');
        env.escrow_manager.assign_role(user, 'user');
        
        // Test 1: Operator can perform operational tasks
        set_caller_address(operator);
        let operator_task = env.escrow_manager.rebalance_funds();
        assert(operator_task, 'Operator failed to perform operational task');
        
        // Test 2: Auditor can read but not modify
        set_caller_address(auditor);
        let audit_data = env.escrow_manager.get_audit_trail();
        assert(audit_data.len() > 0, 'Auditor failed to read audit data');
        
        let auditor_modify = env.escrow_manager.rebalance_funds();
        assert(!auditor_modify, 'Auditor succeeded in modifying state');
        
        // Test 3: User has limited permissions
        set_caller_address(user);
        env.setup_user_balance(user, 50000000);
        
        let user_stream = env.stream_manager.create_stream(
            env.legitimate_user,
            25000000,
            2500,
            3600
        );
        assert(user_stream != 0, 'User failed to create stream');
        
        let user_admin_task = env.escrow_manager.rebalance_funds();
        assert(!user_admin_task, 'User succeeded in admin task');
        
        // Test 4: Role revocation works
        set_caller_address(env.admin);
        let revoke_result = env.escrow_manager.revoke_role(operator, 'operator');
        assert(revoke_result, 'Failed to revoke role');
        
        set_caller_address(operator);
        let revoked_task = env.escrow_manager.rebalance_funds();
        assert(!revoked_task, 'Revoked role still has permissions');
        
        env.cleanup();
    }

    #[test]
    fn test_time_locked_operations() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Test time-locked critical operations
        set_caller_address(env.admin);
        
        // Test 1: Initiate time-locked operation
        let timelock_id = env.escrow_manager.initiate_timelock_operation(
            'upgrade_contract',
            86400 // 24 hour delay
        );
        assert(timelock_id != 0, 'Failed to initiate timelock operation');
        
        // Test 2: Cannot execute before timelock expires
        let premature_execution = env.escrow_manager.execute_timelock_operation(timelock_id);
        assert(!premature_execution, 'Premature timelock execution succeeded');
        
        // Test 3: Can cancel during timelock period
        let cancel_result = env.escrow_manager.cancel_timelock_operation(timelock_id);
        assert(cancel_result, 'Failed to cancel timelock operation');
        
        // Test 4: Cannot execute cancelled operation
        env.advance_time(86400); // Wait for timelock
        let cancelled_execution = env.escrow_manager.execute_timelock_operation(timelock_id);
        assert(!cancelled_execution, 'Cancelled timelock operation executed');
        
        // Test 5: Can execute after timelock expires
        let new_timelock_id = env.escrow_manager.initiate_timelock_operation(
            'upgrade_contract',
            3600 // 1 hour delay
        );
        
        env.advance_time(3600);
        let valid_execution = env.escrow_manager.execute_timelock_operation(new_timelock_id);
        assert(valid_execution, 'Valid timelock execution failed');
        
        env.cleanup();
    }
}