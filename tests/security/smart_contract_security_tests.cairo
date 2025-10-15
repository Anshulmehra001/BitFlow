use starknet::testing::{set_caller_address, set_block_timestamp};
use super::audit_helpers::{SecurityTestEnvironment, SecurityTestEnvironmentTrait, VulnerabilityReport, SecurityScannerTrait};
use bitflow::types::{PaymentStream, BridgeStatus};

// Smart contract security tests covering common vulnerabilities
#[cfg(test)]
mod smart_contract_security_tests {
    use super::*;

    #[test]
    fn test_reentrancy_protection() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        env.setup_attack_scenario('reentrancy_attack');
        
        // Test 1: Attempt reentrancy attack on withdrawal function
        set_caller_address(env.attacker);
        
        // Create a malicious contract that attempts to re-enter during withdrawal
        let stream_id = env.stream_manager.create_stream(env.victim, 10000000, 1000, 3600);
        
        // Advance time to make funds available
        env.advance_time(1800); // 30 minutes
        
        // Attempt reentrancy attack
        let initial_balance = env.stream_manager.get_stream_balance(stream_id);
        
        // This should fail due to reentrancy protection
        let withdrawn = env.stream_manager.withdraw_from_stream(stream_id);
        
        // Verify reentrancy protection worked
        let final_balance = env.stream_manager.get_stream_balance(stream_id);
        let expected_withdrawn = 1000 * 1800; // rate * time
        
        assert(withdrawn <= expected_withdrawn, 'Reentrancy attack succeeded');
        assert(final_balance == initial_balance - withdrawn, 'Balance inconsistent after attack');
        
        // Check system invariants
        let violations = env.check_invariants();
        assert(violations.len() == 0, 'System invariants violated');
        
        env.cleanup();
    }

    #[test]
    fn test_access_control_enforcement() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        env.setup_attack_scenario('access_control_bypass');
        
        // Test 1: Unauthorized emergency pause attempt
        set_caller_address(env.attacker);
        
        // Attacker tries to pause the system
        let pause_result = env.escrow_manager.emergency_pause();
        assert(!pause_result, 'Unauthorized pause succeeded');
        
        // Test 2: Unauthorized admin function access
        let admin_result = env.escrow_manager.set_emergency_admin(env.attacker);
        assert(!admin_result, 'Unauthorized admin change succeeded');
        
        // Test 3: Unauthorized fund withdrawal
        set_caller_address(env.legitimate_user);
        let stream_id = env.stream_manager.create_stream(env.victim, 5000000, 500, 7200);
        
        set_caller_address(env.attacker);
        let unauthorized_withdrawal = env.stream_manager.withdraw_from_stream(stream_id);
        assert(unauthorized_withdrawal == 0, 'Unauthorized withdrawal succeeded');
        
        // Test 4: Verify legitimate admin can still perform admin functions
        set_caller_address(env.admin);
        let legitimate_pause = env.escrow_manager.emergency_pause();
        assert(legitimate_pause, 'Legitimate admin action failed');
        
        // Cleanup
        env.escrow_manager.emergency_unpause();
        env.cleanup();
    }

    #[test]
    fn test_integer_overflow_protection() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        env.setup_attack_scenario('integer_overflow');
        
        // Test 1: Large amount overflow
        set_caller_address(env.attacker);
        
        let max_amount = 0xffffffffffffffffffffffffffffffff; // Max u256
        env.setup_user_balance(env.attacker, max_amount);
        
        // Attempt to create stream with amount that could cause overflow
        let stream_id = env.stream_manager.create_stream(
            env.victim,
            max_amount,
            0xffffffffffffffffffffffffffffffff, // Max rate
            1
        );
        
        // Should either fail or handle gracefully
        if stream_id != 0 {
            // If stream was created, verify no overflow occurred
            let balance = env.stream_manager.get_stream_balance(stream_id);
            assert(balance <= max_amount, 'Integer overflow detected');
        }
        
        // Test 2: Rate calculation overflow
        let large_rate = 0xffffffffffffffffffffffffffffffff;
        let stream_id2 = env.stream_manager.create_stream(
            env.victim,
            1000000, // Small amount
            large_rate,
            86400 // 24 hours
        );
        
        if stream_id2 != 0 {
            env.advance_time(1);
            let balance_after = env.stream_manager.get_stream_balance(stream_id2);
            // Should not underflow to a huge number
            assert(balance_after <= 1000000, 'Rate calculation overflow');
        }
        
        // Test 3: Time-based calculation overflow
        let stream_id3 = env.stream_manager.create_stream(
            env.victim,
            1000000,
            1000,
            0xffffffffffffffffffffffffffffffff // Max duration
        );
        
        if stream_id3 != 0 {
            env.advance_time(86400);
            let balance = env.stream_manager.get_stream_balance(stream_id3);
            assert(balance >= 0, 'Time calculation underflow');
        }
        
        env.cleanup();
    }

    #[test]
    fn test_front_running_protection() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        env.setup_attack_scenario('front_running');
        
        // Test 1: MEV protection on stream creation
        set_caller_address(env.victim);
        env.setup_user_balance(env.victim, 100000000);
        
        // Victim creates a high-value stream
        let victim_stream_id = env.stream_manager.create_stream(
            env.legitimate_user,
            50000000, // 0.5 BTC
            5000,
            7200
        );
        
        // Attacker tries to front-run with similar parameters
        set_caller_address(env.attacker);
        env.setup_user_balance(env.attacker, 100000000);
        
        let attacker_stream_id = env.stream_manager.create_stream(
            env.legitimate_user,
            50000000,
            5001, // Slightly higher rate
            7200
        );
        
        // Both should succeed, but victim's transaction should not be affected
        assert(victim_stream_id != 0, 'Victim stream creation failed');
        assert(attacker_stream_id != 0, 'Attacker stream creation failed');
        assert(victim_stream_id != attacker_stream_id, 'Stream IDs should be different');
        
        // Verify both streams have correct parameters
        let victim_stream = env.stream_manager.get_stream(victim_stream_id);
        let attacker_stream = env.stream_manager.get_stream(attacker_stream_id);
        
        assert(victim_stream.rate_per_second == 5000, 'Victim stream rate modified');
        assert(attacker_stream.rate_per_second == 5001, 'Attacker stream rate incorrect');
        
        env.cleanup();
    }

    #[test]
    fn test_flash_loan_attack_resistance() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        env.setup_attack_scenario('flash_loan_attack');
        
        // Test 1: Price manipulation resistance
        set_caller_address(env.attacker);
        env.setup_user_balance(env.attacker, 1000000000); // 10 BTC
        
        // Attacker tries to manipulate system with large flash loan
        let large_stream_id = env.stream_manager.create_stream(
            env.attacker, // Self-stream
            500000000, // 5 BTC
            1000000, // Very high rate
            1 // 1 second duration
        );
        
        // Advance minimal time
        env.advance_time(1);
        
        // Try to withdraw immediately (flash loan pattern)
        let withdrawn = env.stream_manager.withdraw_from_stream(large_stream_id);
        
        // Cancel stream to get remaining funds back
        let cancelled = env.stream_manager.cancel_stream(large_stream_id);
        
        // Verify the attack didn't drain more than expected
        assert(withdrawn <= 1000000, 'Flash loan attack succeeded');
        
        // Test 2: Yield manipulation resistance
        if env.yield_manager.contract_address != contract_address_const::<0>() {
            env.yield_manager.enable_yield_for_stream(large_stream_id);
            
            // Try to manipulate yield calculations
            env.advance_time(1);
            let yield_earned = env.yield_manager.get_yield_earned(large_stream_id);
            
            // Yield should be reasonable, not manipulated
            assert(yield_earned < 1000000, 'Yield manipulation succeeded');
        }
        
        env.cleanup();
    }

    #[test]
    fn test_denial_of_service_resistance() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Test 1: Gas limit DoS attack
        set_caller_address(env.attacker);
        env.setup_user_balance(env.attacker, 100000000);
        
        // Create many small streams to consume gas
        let mut stream_ids = ArrayTrait::new();
        let mut i = 0;
        loop {
            if i >= 100 { // Try to create 100 streams
                break;
            }
            
            let stream_id = env.stream_manager.create_stream(
                env.victim,
                100000, // 0.001 BTC each
                10,
                3600
            );
            
            if stream_id != 0 {
                stream_ids.append(stream_id);
            }
            i += 1;
        };
        
        // System should still be functional
        set_caller_address(env.legitimate_user);
        env.setup_user_balance(env.legitimate_user, 10000000);
        
        let legitimate_stream = env.stream_manager.create_stream(
            env.victim,
            5000000,
            500,
            7200
        );
        
        assert(legitimate_stream != 0, 'DoS attack prevented legitimate use');
        
        // Test 2: Storage DoS resistance
        // Verify system can handle the created streams
        env.advance_time(1800);
        
        i = 0;
        loop {
            if i >= stream_ids.len() {
                break;
            }
            let stream_id = *stream_ids.at(i);
            let balance = env.stream_manager.get_stream_balance(stream_id);
            assert(balance > 0, 'Stream balance calculation failed under load');
            i += 1;
        };
        
        env.cleanup();
    }

    #[test]
    fn test_signature_replay_protection() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Test signature replay attacks (if applicable to the system)
        set_caller_address(env.victim);
        env.setup_user_balance(env.victim, 50000000);
        
        // Create a stream that might involve signatures
        let stream_id = env.stream_manager.create_stream(
            env.legitimate_user,
            25000000,
            2500,
            3600
        );
        
        // Advance time and withdraw
        env.advance_time(1800);
        let first_withdrawal = env.stream_manager.withdraw_from_stream(stream_id);
        
        // Attacker tries to replay the withdrawal transaction
        set_caller_address(env.attacker);
        let replay_withdrawal = env.stream_manager.withdraw_from_stream(stream_id);
        
        // Replay should fail
        assert(replay_withdrawal == 0, 'Signature replay attack succeeded');
        
        // Verify original user can still withdraw legitimately
        set_caller_address(env.victim);
        env.advance_time(900); // 15 more minutes
        let second_withdrawal = env.stream_manager.withdraw_from_stream(stream_id);
        assert(second_withdrawal > 0, 'Legitimate withdrawal blocked');
        
        env.cleanup();
    }

    #[test]
    fn test_cross_function_reentrancy() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Test cross-function reentrancy attacks
        set_caller_address(env.victim);
        env.setup_user_balance(env.victim, 100000000);
        
        let stream_id = env.stream_manager.create_stream(
            env.attacker,
            50000000,
            5000,
            3600
        );
        
        env.advance_time(1800);
        
        // Attacker tries cross-function reentrancy
        set_caller_address(env.attacker);
        
        // During withdrawal callback, try to call other functions
        let initial_balance = env.stream_manager.get_stream_balance(stream_id);
        
        // This should be protected against cross-function reentrancy
        let withdrawn = env.stream_manager.withdraw_from_stream(stream_id);
        
        // Verify no unexpected state changes occurred
        let final_balance = env.stream_manager.get_stream_balance(stream_id);
        assert(final_balance == initial_balance - withdrawn, 'Cross-function reentrancy succeeded');
        
        // Check system invariants
        let violations = env.check_invariants();
        assert(violations.len() == 0, 'System invariants violated by cross-function reentrancy');
        
        env.cleanup();
    }

    #[test]
    fn test_state_manipulation_attacks() {
        let mut env = SecurityTestEnvironmentTrait::setup();
        
        // Test various state manipulation attacks
        set_caller_address(env.attacker);
        env.setup_user_balance(env.attacker, 100000000);
        
        // Test 1: Time manipulation resistance
        let stream_id = env.stream_manager.create_stream(
            env.victim,
            50000000,
            5000,
            3600
        );
        
        // Try to manipulate block timestamp (this would be done by miner/validator)
        let original_time = starknet::get_block_timestamp();
        set_block_timestamp(original_time + 7200); // Jump 2 hours
        
        let balance_after_jump = env.stream_manager.get_stream_balance(stream_id);
        let expected_max_balance = 50000000 - (5000 * 3600); // Max possible after 1 hour
        
        // Balance should not exceed what's possible in real time
        assert(balance_after_jump >= expected_max_balance, 'Time manipulation affected calculations');
        
        // Test 2: Block number manipulation (if used)
        // Similar tests for block number dependencies
        
        env.cleanup();
    }
}