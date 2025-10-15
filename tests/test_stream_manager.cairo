#[cfg(test)]
mod tests {
    use starknet::{ContractAddress, contract_address_const};
    use starknet::testing::{set_caller_address, set_block_timestamp};
    use bitflow::contracts::stream_manager::{StreamManager};
    use bitflow::interfaces::stream_manager::{IStreamManagerDispatcher, IStreamManagerDispatcherTrait};
    use bitflow::types::{PaymentStream, BitFlowError};
    use snforge_std::{declare, ContractClassTrait};

    fn setup() -> (IStreamManagerDispatcher, ContractAddress, ContractAddress) {
        let owner = contract_address_const::<'owner'>();
        let sender = contract_address_const::<'sender'>();
        let recipient = contract_address_const::<'recipient'>();
        
        // Deploy StreamManager contract
        let contract_class = declare("StreamManager").unwrap();
        let mut constructor_calldata = ArrayTrait::new();
        constructor_calldata.append(owner.into());
        
        let (contract_address, _) = contract_class.deploy(@constructor_calldata).unwrap();
        let dispatcher = IStreamManagerDispatcher { contract_address };
        
        // Set initial timestamp
        set_block_timestamp(1000);
        
        (dispatcher, sender, recipient)
    }

    #[test]
    fn test_create_stream_success() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let amount = 1000_u256;
        let rate = 10_u256; // 10 units per second
        let duration = 100_u64; // 100 seconds
        
        let stream_id = stream_manager.create_stream(recipient, amount, rate, duration);
        
        // Verify stream was created
        assert(stream_id == 1, 'Stream ID should be 1');
        
        // Verify stream details
        let stream = stream_manager.get_stream(stream_id);
        assert(stream.id == stream_id, 'Stream ID mismatch');
        assert(stream.sender == sender, 'Sender mismatch');
        assert(stream.recipient == recipient, 'Recipient mismatch');
        assert(stream.total_amount == amount, 'Amount mismatch');
        assert(stream.rate_per_second == rate, 'Rate mismatch');
        assert(stream.start_time == 1000, 'Start time mismatch');
        assert(stream.end_time == 1100, 'End time mismatch');
        assert(stream.withdrawn_amount == 0, 'Withdrawn amount should be 0');
        assert(stream.is_active == true, 'Stream should be active');
        assert(stream.yield_enabled == false, 'Yield should be disabled');
        
        // Verify stream count
        assert(stream_manager.get_stream_count() == 1, 'Stream count should be 1');
        
        // Verify stream is active
        assert(stream_manager.is_stream_active(stream_id) == true, 'Stream should be active');
    }

    #[test]
    fn test_create_multiple_streams() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create first stream
        let stream_id1 = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Create second stream
        let stream_id2 = stream_manager.create_stream(recipient, 2000, 20, 200);
        
        assert(stream_id1 == 1, 'First stream ID should be 1');
        assert(stream_id2 == 2, 'Second stream ID should be 2');
        assert(stream_manager.get_stream_count() == 2, 'Stream count should be 2');
        
        // Verify both streams exist and are different
        let stream1 = stream_manager.get_stream(stream_id1);
        let stream2 = stream_manager.get_stream(stream_id2);
        
        assert(stream1.total_amount == 1000, 'Stream 1 amount mismatch');
        assert(stream2.total_amount == 2000, 'Stream 2 amount mismatch');
    }

    #[test]
    fn test_get_user_streams() {
        let (stream_manager, sender, recipient) = setup();
        let another_recipient = contract_address_const::<'another_recipient'>();
        
        set_caller_address(sender);
        
        // Create streams with different recipients
        let stream_id1 = stream_manager.create_stream(recipient, 1000, 10, 100);
        let stream_id2 = stream_manager.create_stream(another_recipient, 2000, 20, 200);
        let stream_id3 = stream_manager.create_stream(recipient, 3000, 30, 300);
        
        // Check sender's streams (should have all 3)
        let sender_streams = stream_manager.get_user_streams(sender);
        assert(sender_streams.len() == 3, 'Sender should have 3 streams');
        
        // Check first recipient's streams (should have 2)
        let recipient_streams = stream_manager.get_user_streams(recipient);
        assert(recipient_streams.len() == 2, 'Recipient should have 2 streams');
        
        // Check second recipient's streams (should have 1)
        let another_recipient_streams = stream_manager.get_user_streams(another_recipient);
        assert(another_recipient_streams.len() == 1, 'Another recipient should have 1 stream');
    }

    #[test]
    fn test_cancel_stream_success() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Verify stream is active
        assert(stream_manager.is_stream_active(stream_id) == true, 'Stream should be active');
        
        // Cancel stream
        let success = stream_manager.cancel_stream(stream_id);
        assert(success == true, 'Cancel should succeed');
        
        // Verify stream is no longer active
        assert(stream_manager.is_stream_active(stream_id) == false, 'Stream should be inactive');
        
        // Verify stream details are updated
        let stream = stream_manager.get_stream(stream_id);
        assert(stream.is_active == false, 'Stream should be inactive');
    }

    #[test]
    #[should_panic(expected: ('Stream not found',))]
    fn test_cancel_nonexistent_stream() {
        let (stream_manager, sender, _) = setup();
        set_caller_address(sender);
        
        // Try to cancel non-existent stream
        stream_manager.cancel_stream(999);
    }

    #[test]
    #[should_panic(expected: ('Unauthorized access',))]
    fn test_cancel_stream_unauthorized() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Try to cancel as recipient (should fail)
        set_caller_address(recipient);
        stream_manager.cancel_stream(stream_id);
    }

    #[test]
    #[should_panic(expected: ('Stream not active',))]
    fn test_cancel_already_cancelled_stream() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create and cancel stream
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        stream_manager.cancel_stream(stream_id);
        
        // Try to cancel again (should fail)
        stream_manager.cancel_stream(stream_id);
    }

    #[test]
    #[should_panic(expected: ('Stream not found',))]
    fn test_get_nonexistent_stream() {
        let (stream_manager, _, _) = setup();
        
        // Try to get non-existent stream
        stream_manager.get_stream(999);
    }

    #[test]
    #[should_panic(expected: ('Invalid stream parameters',))]
    fn test_create_stream_zero_recipient() {
        let (stream_manager, sender, _) = setup();
        set_caller_address(sender);
        
        let zero_address = contract_address_const::<0>();
        stream_manager.create_stream(zero_address, 1000, 10, 100);
    }

    #[test]
    #[should_panic(expected: ('Zero amount',))]
    fn test_create_stream_zero_amount() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        stream_manager.create_stream(recipient, 0, 10, 100);
    }

    #[test]
    #[should_panic(expected: ('Invalid stream parameters',))]
    fn test_create_stream_zero_rate() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        stream_manager.create_stream(recipient, 1000, 0, 100);
    }

    #[test]
    #[should_panic(expected: ('Invalid time range',))]
    fn test_create_stream_zero_duration() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        stream_manager.create_stream(recipient, 1000, 10, 0);
    }

    #[test]
    #[should_panic(expected: ('Invalid stream parameters',))]
    fn test_create_stream_invalid_rate_duration_ratio() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Rate * duration = 1000 * 100 = 100,000, but amount is only 1000
        // This violates the validation that calculated_total > amount * 2
        stream_manager.create_stream(recipient, 1000, 1000, 100);
    }

    #[test]
    fn test_is_stream_active_false_for_nonexistent() {
        let (stream_manager, _, _) = setup();
        
        // Non-existent stream should return false
        assert(stream_manager.is_stream_active(999) == false, 'Non-existent stream should be inactive');
    }

    #[test]
    fn test_get_user_streams_empty() {
        let (stream_manager, _, _) = setup();
        let user = contract_address_const::<'user'>();
        
        let streams = stream_manager.get_user_streams(user);
        assert(streams.len() == 0, 'User should have no streams');
    }

    #[test]
    fn test_stream_count_starts_at_zero() {
        let (stream_manager, _, _) = setup();
        
        assert(stream_manager.get_stream_count() == 0, 'Initial stream count should be 0');
    }

    // ========== Stream Lifecycle Management Tests ==========

    #[test]
    fn test_pause_stream_by_sender() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Pause stream
        let success = stream_manager.pause_stream(stream_id);
        assert(success == true, 'Pause should succeed');
        
        // Verify stream is paused
        assert(stream_manager.is_stream_paused(stream_id) == true, 'Stream should be paused');
        assert(stream_manager.is_stream_active(stream_id) == false, 'Stream should not be active when paused');
    }

    #[test]
    fn test_pause_stream_by_recipient() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Pause stream as recipient
        set_caller_address(recipient);
        let success = stream_manager.pause_stream(stream_id);
        assert(success == true, 'Pause should succeed');
        
        // Verify stream is paused
        assert(stream_manager.is_stream_paused(stream_id) == true, 'Stream should be paused');
    }

    #[test]
    #[should_panic(expected: ('Unauthorized access',))]
    fn test_pause_stream_unauthorized() {
        let (stream_manager, sender, recipient) = setup();
        let unauthorized = contract_address_const::<'unauthorized'>();
        
        set_caller_address(sender);
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Try to pause as unauthorized user
        set_caller_address(unauthorized);
        stream_manager.pause_stream(stream_id);
    }

    #[test]
    #[should_panic(expected: ('Stream already paused',))]
    fn test_pause_already_paused_stream() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        stream_manager.pause_stream(stream_id);
        
        // Try to pause again
        stream_manager.pause_stream(stream_id);
    }

    #[test]
    fn test_resume_stream_by_sender() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create and pause stream
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        stream_manager.pause_stream(stream_id);
        
        // Advance time while paused
        set_block_timestamp(1050);
        
        // Resume stream
        let success = stream_manager.resume_stream(stream_id);
        assert(success == true, 'Resume should succeed');
        
        // Verify stream is no longer paused
        assert(stream_manager.is_stream_paused(stream_id) == false, 'Stream should not be paused');
        assert(stream_manager.is_stream_active(stream_id) == true, 'Stream should be active');
    }

    #[test]
    fn test_resume_stream_by_recipient() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        stream_manager.pause_stream(stream_id);
        
        // Resume as recipient
        set_caller_address(recipient);
        let success = stream_manager.resume_stream(stream_id);
        assert(success == true, 'Resume should succeed');
        
        assert(stream_manager.is_stream_paused(stream_id) == false, 'Stream should not be paused');
    }

    #[test]
    #[should_panic(expected: ('Stream not paused',))]
    fn test_resume_non_paused_stream() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Try to resume non-paused stream
        stream_manager.resume_stream(stream_id);
    }

    #[test]
    fn test_withdraw_from_stream_basic() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream: 1000 total, 10 per second, 100 seconds
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Advance time by 50 seconds
        set_block_timestamp(1050);
        
        // Withdraw as recipient
        set_caller_address(recipient);
        let withdrawn = stream_manager.withdraw_from_stream(stream_id);
        
        // Should have withdrawn 50 seconds * 10 per second = 500
        assert(withdrawn == 500, 'Should withdraw 500');
        
        // Check stream balance is now 0
        assert(stream_manager.get_stream_balance(stream_id) == 0, 'Balance should be 0 after withdrawal');
        
        // Verify stream state updated
        let stream = stream_manager.get_stream(stream_id);
        assert(stream.withdrawn_amount == 500, 'Withdrawn amount should be 500');
    }

    #[test]
    fn test_withdraw_multiple_times() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // First withdrawal after 30 seconds
        set_block_timestamp(1030);
        set_caller_address(recipient);
        let withdrawn1 = stream_manager.withdraw_from_stream(stream_id);
        assert(withdrawn1 == 300, 'First withdrawal should be 300');
        
        // Second withdrawal after another 20 seconds (total 50 seconds)
        set_block_timestamp(1050);
        let withdrawn2 = stream_manager.withdraw_from_stream(stream_id);
        assert(withdrawn2 == 200, 'Second withdrawal should be 200');
        
        // Total withdrawn should be 500
        let stream = stream_manager.get_stream(stream_id);
        assert(stream.withdrawn_amount == 500, 'Total withdrawn should be 500');
    }

    #[test]
    #[should_panic(expected: ('Unauthorized access',))]
    fn test_withdraw_unauthorized() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Advance time
        set_block_timestamp(1050);
        
        // Try to withdraw as sender (should fail)
        let withdrawn = stream_manager.withdraw_from_stream(stream_id);
    }

    #[test]
    #[should_panic(expected: ('No funds available',))]
    fn test_withdraw_no_funds_available() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Try to withdraw immediately (no time passed)
        set_caller_address(recipient);
        stream_manager.withdraw_from_stream(stream_id);
    }

    #[test]
    fn test_get_stream_balance_over_time() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream: 1000 total, 10 per second
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Check balance at start
        assert(stream_manager.get_stream_balance(stream_id) == 0, 'Initial balance should be 0');
        
        // Check balance after 25 seconds
        set_block_timestamp(1025);
        assert(stream_manager.get_stream_balance(stream_id) == 250, 'Balance after 25s should be 250');
        
        // Check balance after 50 seconds
        set_block_timestamp(1050);
        assert(stream_manager.get_stream_balance(stream_id) == 500, 'Balance after 50s should be 500');
        
        // Check balance after 100 seconds (full duration)
        set_block_timestamp(1100);
        assert(stream_manager.get_stream_balance(stream_id) == 1000, 'Balance after 100s should be 1000');
        
        // Check balance after stream ends (should cap at total amount)
        set_block_timestamp(1150);
        assert(stream_manager.get_stream_balance(stream_id) == 1000, 'Balance should cap at total amount');
    }

    #[test]
    fn test_pause_resume_affects_balance_calculation() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream: 1000 total, 10 per second
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Let 20 seconds pass, then pause
        set_block_timestamp(1020);
        stream_manager.pause_stream(stream_id);
        
        // Balance should be 200 (20 seconds * 10 per second)
        assert(stream_manager.get_stream_balance(stream_id) == 200, 'Balance should be 200 when paused');
        
        // Let 30 more seconds pass while paused
        set_block_timestamp(1050);
        
        // Balance should still be 200 (no progress while paused)
        assert(stream_manager.get_stream_balance(stream_id) == 200, 'Balance should remain 200 while paused');
        
        // Resume stream
        stream_manager.resume_stream(stream_id);
        
        // Let 10 more seconds pass after resume
        set_block_timestamp(1060);
        
        // Balance should be 300 (20 seconds before pause + 10 seconds after resume)
        assert(stream_manager.get_stream_balance(stream_id) == 300, 'Balance should be 300 after resume');
    }

    #[test]
    fn test_withdraw_with_pause_resume_cycle() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Let 20 seconds pass, then pause
        set_block_timestamp(1020);
        stream_manager.pause_stream(stream_id);
        
        // Withdraw available funds (should be 200)
        set_caller_address(recipient);
        let withdrawn1 = stream_manager.withdraw_from_stream(stream_id);
        assert(withdrawn1 == 200, 'First withdrawal should be 200');
        
        // Let time pass while paused (should not affect balance)
        set_block_timestamp(1050);
        
        // Resume stream
        set_caller_address(sender);
        stream_manager.resume_stream(stream_id);
        
        // Let 10 more seconds pass
        set_block_timestamp(1060);
        
        // Withdraw again (should be 100 for the 10 seconds after resume)
        set_caller_address(recipient);
        let withdrawn2 = stream_manager.withdraw_from_stream(stream_id);
        assert(withdrawn2 == 100, 'Second withdrawal should be 100');
        
        // Total withdrawn should be 300
        let stream = stream_manager.get_stream(stream_id);
        assert(stream.withdrawn_amount == 300, 'Total withdrawn should be 300');
    }

    #[test]
    fn test_is_stream_paused_false_for_nonexistent() {
        let (stream_manager, _, _) = setup();
        
        assert(stream_manager.is_stream_paused(999) == false, 'Non-existent stream should not be paused');
    }

    #[test]
    fn test_is_stream_paused_false_for_active_stream() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        assert(stream_manager.is_stream_paused(stream_id) == false, 'Active stream should not be paused');
    }

    #[test]
    #[should_panic(expected: ('Stream not active',))]
    fn test_withdraw_from_cancelled_stream() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Cancel stream
        stream_manager.cancel_stream(stream_id);
        
        // Try to withdraw from cancelled stream
        set_block_timestamp(1050);
        set_caller_address(recipient);
        stream_manager.withdraw_from_stream(stream_id);
    }

    #[test]
    #[should_panic(expected: ('Stream not active',))]
    fn test_pause_cancelled_stream() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        stream_manager.cancel_stream(stream_id);
        
        // Try to pause cancelled stream
        stream_manager.pause_stream(stream_id);
    }

    // ========== Continuous Payment Distribution Tests ==========

    #[test]
    fn test_process_automatic_payment_basic() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream: 1000 total, 10 per second, 100 seconds
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Advance time by 30 seconds
        set_block_timestamp(1030);
        
        // Process automatic payment
        let payment_amount = stream_manager.process_automatic_payment(stream_id);
        
        // Should have processed 30 seconds * 10 per second = 300
        assert(payment_amount == 300, 'Payment amount should be 300');
        
        // Check accumulated payments
        assert(stream_manager.get_accumulated_payments(stream_id) == 300, 'Accumulated should be 300');
        
        // Check last payment time
        assert(stream_manager.get_last_payment_time(stream_id) == 1030, 'Last payment time should be 1030');
    }

    #[test]
    fn test_process_automatic_payment_multiple_times() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // First automatic payment after 20 seconds
        set_block_timestamp(1020);
        let payment1 = stream_manager.process_automatic_payment(stream_id);
        assert(payment1 == 200, 'First payment should be 200');
        
        // Second automatic payment after another 30 seconds (total 50 seconds)
        set_block_timestamp(1050);
        let payment2 = stream_manager.process_automatic_payment(stream_id);
        assert(payment2 == 300, 'Second payment should be 300');
        
        // Total accumulated should be 500
        assert(stream_manager.get_accumulated_payments(stream_id) == 500, 'Total accumulated should be 500');
        
        // Last payment time should be updated
        assert(stream_manager.get_last_payment_time(stream_id) == 1050, 'Last payment time should be 1050');
    }

    #[test]
    fn test_automatic_payment_with_manual_withdrawal() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Process automatic payment after 20 seconds
        set_block_timestamp(1020);
        let auto_payment = stream_manager.process_automatic_payment(stream_id);
        assert(auto_payment == 200, 'Auto payment should be 200');
        
        // Advance time and manually withdraw
        set_block_timestamp(1050);
        set_caller_address(recipient);
        let manual_withdrawal = stream_manager.withdraw_from_stream(stream_id);
        
        // Manual withdrawal should only get the amount since last automatic payment
        // 30 seconds * 10 per second = 300
        assert(manual_withdrawal == 300, 'Manual withdrawal should be 300');
        
        // Total distributed should be 500 (200 auto + 300 manual)
        let stream = stream_manager.get_stream(stream_id);
        assert(stream.withdrawn_amount == 300, 'Withdrawn amount should be 300');
        assert(stream_manager.get_accumulated_payments(stream_id) == 200, 'Accumulated should be 200');
    }

    #[test]
    fn test_automatic_payment_caps_at_total_amount() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream: 500 total, 10 per second, 100 seconds
        let stream_id = stream_manager.create_stream(recipient, 500, 10, 100);
        
        // Advance time by 60 seconds (would be 600 if uncapped)
        set_block_timestamp(1060);
        
        // Process automatic payment
        let payment_amount = stream_manager.process_automatic_payment(stream_id);
        
        // Should be capped at total amount (500)
        assert(payment_amount == 500, 'Payment should be capped at 500');
        
        // Stream should be marked as completed
        assert(stream_manager.is_stream_active(stream_id) == false, 'Stream should be completed');
    }

    #[test]
    fn test_batch_process_payments() {
        let (stream_manager, sender, recipient) = setup();
        let recipient2 = contract_address_const::<'recipient2'>();
        
        set_caller_address(sender);
        
        // Create multiple streams
        let stream_id1 = stream_manager.create_stream(recipient, 1000, 10, 100);
        let stream_id2 = stream_manager.create_stream(recipient2, 2000, 20, 100);
        
        // Advance time by 25 seconds
        set_block_timestamp(1025);
        
        // Batch process payments
        let mut stream_ids = ArrayTrait::new();
        stream_ids.append(stream_id1);
        stream_ids.append(stream_id2);
        
        let total_processed = stream_manager.batch_process_payments(stream_ids);
        
        // Stream 1: 25 * 10 = 250
        // Stream 2: 25 * 20 = 500
        // Total: 750
        assert(total_processed == 750, 'Total processed should be 750');
        
        // Check individual accumulated amounts
        assert(stream_manager.get_accumulated_payments(stream_id1) == 250, 'Stream 1 accumulated should be 250');
        assert(stream_manager.get_accumulated_payments(stream_id2) == 500, 'Stream 2 accumulated should be 500');
    }

    #[test]
    fn test_automatic_payment_with_paused_stream() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Let 20 seconds pass, then pause
        set_block_timestamp(1020);
        stream_manager.pause_stream(stream_id);
        
        // Try to process automatic payment while paused (should fail)
        let payment_amount = stream_manager.process_automatic_payment(stream_id);
        assert(payment_amount == 0, 'Payment should be 0 for paused stream');
    }

    #[test]
    #[should_panic(expected: ('Stream is paused',))]
    fn test_process_automatic_payment_paused_stream_panics() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Pause stream immediately
        stream_manager.pause_stream(stream_id);
        
        // Try to process automatic payment (should panic)
        stream_manager.process_automatic_payment(stream_id);
    }

    #[test]
    fn test_automatic_payment_after_resume() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Let 20 seconds pass, then pause
        set_block_timestamp(1020);
        stream_manager.pause_stream(stream_id);
        
        // Let 30 seconds pass while paused
        set_block_timestamp(1050);
        
        // Resume stream
        stream_manager.resume_stream(stream_id);
        
        // Process automatic payment immediately after resume
        let payment_amount = stream_manager.process_automatic_payment(stream_id);
        
        // Should only process the 20 seconds before pause (no time after resume yet)
        assert(payment_amount == 200, 'Payment should be 200');
        
        // Let 10 more seconds pass and process again
        set_block_timestamp(1060);
        let payment_amount2 = stream_manager.process_automatic_payment(stream_id);
        
        // Should process the 10 seconds after resume
        assert(payment_amount2 == 100, 'Second payment should be 100');
    }

    #[test]
    #[should_panic(expected: ('Stream not found',))]
    fn test_process_automatic_payment_nonexistent_stream() {
        let (stream_manager, _, _) = setup();
        
        stream_manager.process_automatic_payment(999);
    }

    #[test]
    #[should_panic(expected: ('Stream not active',))]
    fn test_process_automatic_payment_cancelled_stream() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        stream_manager.cancel_stream(stream_id);
        
        stream_manager.process_automatic_payment(stream_id);
    }

    #[test]
    fn test_get_accumulated_payments_zero_for_new_stream() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        assert(stream_manager.get_accumulated_payments(stream_id) == 0, 'Initial accumulated should be 0');
    }

    #[test]
    fn test_get_last_payment_time_zero_for_new_stream() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        assert(stream_manager.get_last_payment_time(stream_id) == 0, 'Initial last payment time should be 0');
    }

    #[test]
    fn test_automatic_payment_no_double_processing() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Advance time and process payment
        set_block_timestamp(1030);
        let payment1 = stream_manager.process_automatic_payment(stream_id);
        assert(payment1 == 300, 'First payment should be 300');
        
        // Process again at same timestamp (should be 0)
        let payment2 = stream_manager.process_automatic_payment(stream_id);
        assert(payment2 == 0, 'Second payment at same time should be 0');
        
        // Accumulated should still be 300
        assert(stream_manager.get_accumulated_payments(stream_id) == 300, 'Accumulated should remain 300');
    }

    #[test]
    fn test_stream_balance_accounts_for_automatic_payments() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Advance time by 50 seconds
        set_block_timestamp(1050);
        
        // Process automatic payment
        let auto_payment = stream_manager.process_automatic_payment(stream_id);
        assert(auto_payment == 500, 'Auto payment should be 500');
        
        // Stream balance should now be 0 (all distributed automatically)
        assert(stream_manager.get_stream_balance(stream_id) == 0, 'Stream balance should be 0');
        
        // Advance time by 20 more seconds
        set_block_timestamp(1070);
        
        // Stream balance should be 200 (20 seconds * 10 per second)
        assert(stream_manager.get_stream_balance(stream_id) == 200, 'Stream balance should be 200');
    }

    #[test]
    fn test_batch_process_empty_array() {
        let (stream_manager, _, _) = setup();
        
        let empty_array = ArrayTrait::new();
        let total_processed = stream_manager.batch_process_payments(empty_array);
        
        assert(total_processed == 0, 'Empty batch should process 0');
    }

    #[test]
    fn test_automatic_payment_precision() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream with precise rate: 1000 total, 7 per second (not evenly divisible)
        let stream_id = stream_manager.create_stream(recipient, 1000, 7, 143); // 143 * 7 = 1001, but capped at 1000
        
        // Advance time by 13 seconds
        set_block_timestamp(1013);
        
        // Process automatic payment
        let payment_amount = stream_manager.process_automatic_payment(stream_id);
        
        // Should be exactly 13 * 7 = 91
        assert(payment_amount == 91, 'Payment should be 91');
        
        // Process again after 17 more seconds (total 30 seconds)
        set_block_timestamp(1030);
        let payment_amount2 = stream_manager.process_automatic_payment(stream_id);
        
        // Should be 17 * 7 = 119
        assert(payment_amount2 == 119, 'Second payment should be 119');
        
        // Total accumulated should be 210
        assert(stream_manager.get_accumulated_payments(stream_id) == 210, 'Total accumulated should be 210');
    }
}    //
 ========== Additional Edge Case Tests for Continuous Payment Distribution ==========

    #[test]
    fn test_automatic_payment_at_stream_end_time() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream: 1000 total, 10 per second, 100 seconds (ends at timestamp 1100)
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Advance to exactly stream end time
        set_block_timestamp(1100);
        
        // Process automatic payment
        let payment_amount = stream_manager.process_automatic_payment(stream_id);
        
        // Should process the full amount
        assert(payment_amount == 1000, 'Payment should be full amount');
        
        // Stream should be completed
        assert(stream_manager.is_stream_active(stream_id) == false, 'Stream should be completed');
    }

    #[test]
    fn test_automatic_payment_beyond_stream_end_time() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream: 1000 total, 10 per second, 100 seconds
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Advance beyond stream end time
        set_block_timestamp(1150);
        
        // Process automatic payment
        let payment_amount = stream_manager.process_automatic_payment(stream_id);
        
        // Should be capped at total amount
        assert(payment_amount == 1000, 'Payment should be capped at total');
        
        // Stream should be completed
        assert(stream_manager.is_stream_active(stream_id) == false, 'Stream should be completed');
    }

    #[test]
    fn test_mixed_automatic_and_manual_payments() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        let stream_id = stream_manager.create_stream(recipient, 1000, 10, 100);
        
        // Process automatic payment after 20 seconds
        set_block_timestamp(1020);
        let auto1 = stream_manager.process_automatic_payment(stream_id);
        assert(auto1 == 200, 'First auto payment should be 200');
        
        // Manual withdrawal after 30 seconds (10 seconds since last auto)
        set_block_timestamp(1030);
        set_caller_address(recipient);
        let manual1 = stream_manager.withdraw_from_stream(stream_id);
        assert(manual1 == 100, 'Manual withdrawal should be 100');
        
        // Another automatic payment after 50 seconds (20 seconds since last manual)
        set_block_timestamp(1050);
        set_caller_address(sender);
        let auto2 = stream_manager.process_automatic_payment(stream_id);
        assert(auto2 == 200, 'Second auto payment should be 200');
        
        // Check totals
        let stream = stream_manager.get_stream(stream_id);
        assert(stream.withdrawn_amount == 100, 'Total withdrawn should be 100');
        assert(stream_manager.get_accumulated_payments(stream_id) == 400, 'Total accumulated should be 400');
        
        // Remaining balance should be 500
        assert(stream_manager.get_stream_balance(stream_id) == 500, 'Remaining balance should be 500');
    }

    #[test]
    fn test_automatic_payment_with_very_small_amounts() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream with very small rate: 100 total, 1 per second
        let stream_id = stream_manager.create_stream(recipient, 100, 1, 100);
        
        // Process payment after 1 second
        set_block_timestamp(1001);
        let payment = stream_manager.process_automatic_payment(stream_id);
        assert(payment == 1, 'Payment should be 1');
        
        // Process again after another second
        set_block_timestamp(1002);
        let payment2 = stream_manager.process_automatic_payment(stream_id);
        assert(payment2 == 1, 'Second payment should be 1');
        
        assert(stream_manager.get_accumulated_payments(stream_id) == 2, 'Total accumulated should be 2');
    }

    #[test]
    fn test_batch_process_with_mixed_stream_states() {
        let (stream_manager, sender, recipient) = setup();
        let recipient2 = contract_address_const::<'recipient2'>();
        
        set_caller_address(sender);
        
        // Create multiple streams
        let stream_id1 = stream_manager.create_stream(recipient, 1000, 10, 100);
        let stream_id2 = stream_manager.create_stream(recipient2, 2000, 20, 100);
        let stream_id3 = stream_manager.create_stream(recipient, 500, 5, 100);
        
        // Pause one stream
        stream_manager.pause_stream(stream_id2);
        
        // Cancel another stream
        stream_manager.cancel_stream(stream_id3);
        
        // Advance time
        set_block_timestamp(1030);
        
        // Batch process all streams
        let mut stream_ids = ArrayTrait::new();
        stream_ids.append(stream_id1);
        stream_ids.append(stream_id2); // This should fail silently or be skipped
        stream_ids.append(stream_id3); // This should fail silently or be skipped
        
        // Only stream_id1 should be processed successfully
        // The batch function should handle errors gracefully
        let total_processed = stream_manager.batch_process_payments(stream_ids);
        
        // Only stream 1 should contribute: 30 * 10 = 300
        assert(total_processed == 300, 'Only active stream should be processed');
        assert(stream_manager.get_accumulated_payments(stream_id1) == 300, 'Stream 1 should have 300');
        assert(stream_manager.get_accumulated_payments(stream_id2) == 0, 'Paused stream should have 0');
        assert(stream_manager.get_accumulated_payments(stream_id3) == 0, 'Cancelled stream should have 0');
    }

    #[test]
    fn test_automatic_payment_maintains_precision_over_time() {
        let (stream_manager, sender, recipient) = setup();
        set_caller_address(sender);
        
        // Create stream with rate that doesn't divide evenly: 1000 total, 3 per second
        let stream_id = stream_manager.create_stream(recipient, 1000, 3, 334); // 334 * 3 = 1002, but capped at 1000
        
        let mut total_processed = 0_u256;
        let mut current_time = 1000_u64;
        
        // Process payments in small increments
        let mut i = 0;
        while i < 10 {
            current_time += 7; // Add 7 seconds each time
            set_block_timestamp(current_time);
            
            let payment = stream_manager.process_automatic_payment(stream_id);
            total_processed += payment;
            i += 1;
        };
        
        // After 70 seconds (10 * 7), should have processed 70 * 3 = 210
        assert(total_processed == 210, 'Total processed should be 210');
        assert(stream_manager.get_accumulated_payments(stream_id) == 210, 'Accumulated should be 210');
        
        // Process remaining amount
        set_block_timestamp(1334); // Full duration
        let final_payment = stream_manager.process_automatic_payment(stream_id);
        
        // Should process remaining amount to reach exactly 1000
        let expected_final = 1000 - 210;
        assert(final_payment == expected_final, 'Final payment should complete stream');
        assert(stream_manager.get_accumulated_payments(stream_id) == 1000, 'Final accumulated should be 1000');
    }