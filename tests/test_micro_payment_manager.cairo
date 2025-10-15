use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use starknet::testing::{set_caller_address, set_block_timestamp};

use crate::contracts::micro_payment_manager::{
    MicroPaymentManager, IMicroPaymentManagerDispatcher, IMicroPaymentManagerDispatcherTrait
};
use crate::contracts::stream_manager::{
    StreamManager, IStreamManagerDispatcher, IStreamManagerDispatcherTrait
};
use crate::interfaces::micro_payment::{MicroPayment, ContentAccess, UserBalance};
use crate::types::{PaymentStream, BitFlowError};
use crate::utils::time::get_current_time;

// Test constants
const OWNER: felt252 = 'owner';
const CREATOR: felt252 = 'creator';
const USER: felt252 = 'user';
const CONTENT_ID: u256 = 1;
const PRICE_PER_ACCESS: u256 = 1000; // 0.001 units (sub-cent)
const MIN_PAYMENT: u256 = 100; // Minimum payment amount
const STREAM_AMOUNT: u256 = 1000000; // 1 unit
const STREAM_RATE: u256 = 100; // 100 wei per second
const STREAM_DURATION: u64 = 10000; // 10000 seconds

fn setup() -> (IMicroPaymentManagerDispatcher, IStreamManagerDispatcher, ContractAddress, ContractAddress, ContractAddress) {
    let owner = contract_address_const::<OWNER>();
    let creator = contract_address_const::<CREATOR>();
    let user = contract_address_const::<USER>();
    
    // Deploy stream manager first
    let stream_manager = IStreamManagerDispatcher {
        contract_address: starknet::deploy_syscall(
            StreamManager::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![owner.into()].span(),
            false,
        ).unwrap().contract_address
    };
    
    // Deploy micro payment manager
    let micro_payment_manager = IMicroPaymentManagerDispatcher {
        contract_address: starknet::deploy_syscall(
            MicroPaymentManager::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![
                owner.into(),
                stream_manager.contract_address.into(),
                MIN_PAYMENT.into()
            ].span(),
            false,
        ).unwrap().contract_address
    };
    
    (micro_payment_manager, stream_manager, owner, creator, user)
}

fn create_test_stream(
    stream_manager: IStreamManagerDispatcher,
    sender: ContractAddress,
    recipient: ContractAddress
) -> u256 {
    set_caller_address(sender);
    stream_manager.create_stream(recipient, STREAM_AMOUNT, STREAM_RATE, STREAM_DURATION)
}

#[test]
fn test_register_content() {
    let (micro_payment_manager, _, _, creator, _) = setup();
    
    set_caller_address(creator);
    
    // Register content
    let success = micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
    assert(success, 'Content registration failed');
    
    // Verify content was registered
    let content = micro_payment_manager.get_content_info(CONTENT_ID);
    assert(content.content_id == CONTENT_ID, 'Wrong content ID');
    assert(content.creator == creator, 'Wrong creator');
    assert(content.price_per_access == PRICE_PER_ACCESS, 'Wrong price');
    assert(content.is_active, 'Content should be active');
    assert(content.total_accesses == 0, 'Should have no accesses');
    assert(content.total_revenue == 0, 'Should have no revenue');
}

#[test]
#[should_panic(expected: ('Content already exists',))]
fn test_register_duplicate_content() {
    let (micro_payment_manager, _, _, creator, _) = setup();
    
    set_caller_address(creator);
    
    // Register content first time
    micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
    
    // Try to register same content again - should panic
    micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
}

#[test]
#[should_panic(expected: ('Price too low',))]
fn test_register_content_price_too_low() {
    let (micro_payment_manager, _, _, creator, _) = setup();
    
    set_caller_address(creator);
    
    // Try to register content with price below minimum - should panic
    micro_payment_manager.register_content(CONTENT_ID, MIN_PAYMENT - 1);
}

#[test]
fn test_update_content_price() {
    let (micro_payment_manager, _, _, creator, _) = setup();
    
    set_caller_address(creator);
    
    // Register content first
    micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
    
    // Update price
    let new_price = PRICE_PER_ACCESS * 2;
    let success = micro_payment_manager.update_content_price(CONTENT_ID, new_price);
    assert(success, 'Price update failed');
    
    // Verify price was updated
    let content = micro_payment_manager.get_content_info(CONTENT_ID);
    assert(content.price_per_access == new_price, 'Price not updated');
}

#[test]
#[should_panic(expected: ('Unauthorized access',))]
fn test_update_content_price_unauthorized() {
    let (micro_payment_manager, _, _, creator, user) = setup();
    
    set_caller_address(creator);
    micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
    
    // Try to update price as different user - should panic
    set_caller_address(user);
    micro_payment_manager.update_content_price(CONTENT_ID, PRICE_PER_ACCESS * 2);
}

#[test]
fn test_deactivate_content() {
    let (micro_payment_manager, _, _, creator, _) = setup();
    
    set_caller_address(creator);
    
    // Register content first
    micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
    
    // Deactivate content
    let success = micro_payment_manager.deactivate_content(CONTENT_ID);
    assert(success, 'Content deactivation failed');
    
    // Verify content was deactivated
    let content = micro_payment_manager.get_content_info(CONTENT_ID);
    assert(!content.is_active, 'Content should be inactive');
}

#[test]
fn test_can_access_content_with_sufficient_balance() {
    let (micro_payment_manager, stream_manager, _, creator, user) = setup();
    
    // Register content
    set_caller_address(creator);
    micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
    
    // Create stream for user
    let stream_id = create_test_stream(stream_manager, user, creator);
    
    // Advance time to accumulate balance
    set_block_timestamp(get_current_time() + 1000);
    
    // Check if user can access content
    let can_access = micro_payment_manager.can_access_content(user, CONTENT_ID);
    assert(can_access, 'User should be able to access');
}

#[test]
fn test_can_access_content_insufficient_balance() {
    let (micro_payment_manager, _, _, creator, user) = setup();
    
    // Register content
    set_caller_address(creator);
    micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
    
    // Check if user can access content without any streams
    let can_access = micro_payment_manager.can_access_content(user, CONTENT_ID);
    assert(!can_access, 'User should not be able to access');
}

#[test]
fn test_process_micro_payment_success() {
    let (micro_payment_manager, stream_manager, _, creator, user) = setup();
    
    // Register content
    set_caller_address(creator);
    micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
    
    // Create stream for user
    let stream_id = create_test_stream(stream_manager, user, creator);
    
    // Advance time to accumulate balance
    set_block_timestamp(get_current_time() + 1000);
    
    // Process micro payment
    set_caller_address(user);
    let payment_id = micro_payment_manager.process_micro_payment(CONTENT_ID, stream_id);
    assert(payment_id > 0, 'Payment ID should be positive');
    
    // Verify content statistics updated
    let content = micro_payment_manager.get_content_info(CONTENT_ID);
    assert(content.total_accesses == 1, 'Access count should be 1');
    assert(content.total_revenue == PRICE_PER_ACCESS, 'Revenue should match price');
}

#[test]
#[should_panic(expected: ('Insufficient balance for payment',))]
fn test_process_micro_payment_insufficient_balance() {
    let (micro_payment_manager, stream_manager, _, creator, user) = setup();
    
    // Register content
    set_caller_address(creator);
    micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
    
    // Create stream for user but don't advance time (no balance)
    let stream_id = create_test_stream(stream_manager, user, creator);
    
    // Try to process micro payment without sufficient balance - should panic
    set_caller_address(user);
    micro_payment_manager.process_micro_payment(CONTENT_ID, stream_id);
}

#[test]
#[should_panic(expected: ('Content not active',))]
fn test_process_micro_payment_inactive_content() {
    let (micro_payment_manager, stream_manager, _, creator, user) = setup();
    
    // Register and deactivate content
    set_caller_address(creator);
    micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
    micro_payment_manager.deactivate_content(CONTENT_ID);
    
    // Create stream for user
    let stream_id = create_test_stream(stream_manager, user, creator);
    
    // Try to process payment for inactive content - should panic
    set_caller_address(user);
    micro_payment_manager.process_micro_payment(CONTENT_ID, stream_id);
}

#[test]
fn test_set_low_balance_threshold() {
    let (micro_payment_manager, _, _, _, user) = setup();
    
    set_caller_address(user);
    
    let threshold = 5000_u256;
    let success = micro_payment_manager.set_low_balance_threshold(threshold);
    assert(success, 'Setting threshold failed');
    
    // Verify threshold was set
    let balance = micro_payment_manager.get_user_balance(user);
    assert(balance.low_balance_threshold == threshold, 'Threshold not set correctly');
}

#[test]
fn test_is_balance_low() {
    let (micro_payment_manager, stream_manager, _, creator, user) = setup();
    
    // Set low balance threshold
    set_caller_address(user);
    let threshold = 50000_u256; // High threshold
    micro_payment_manager.set_low_balance_threshold(threshold);
    
    // Create small stream
    let stream_id = create_test_stream(stream_manager, user, creator);
    
    // Advance time slightly
    set_block_timestamp(get_current_time() + 100);
    
    // Check if balance is low
    let is_low = micro_payment_manager.is_balance_low(user);
    assert(is_low, 'Balance should be considered low');
}

#[test]
fn test_reserve_and_release_balance() {
    let (micro_payment_manager, stream_manager, _, creator, user) = setup();
    
    // Create stream for user
    let stream_id = create_test_stream(stream_manager, user, creator);
    
    // Advance time to accumulate balance
    set_block_timestamp(get_current_time() + 1000);
    
    let reserve_amount = 5000_u256;
    
    // Reserve balance
    let success = micro_payment_manager.reserve_balance(user, reserve_amount);
    assert(success, 'Balance reservation failed');
    
    // Verify balance was reserved
    let balance = micro_payment_manager.get_user_balance(user);
    assert(balance.reserved_balance == reserve_amount, 'Reserved balance incorrect');
    
    // Release balance
    let success = micro_payment_manager.release_reserved_balance(user, reserve_amount);
    assert(success, 'Balance release failed');
    
    // Verify balance was released
    let balance = micro_payment_manager.get_user_balance(user);
    assert(balance.reserved_balance == 0, 'Reserved balance should be zero');
}

#[test]
#[should_panic(expected: ('Insufficient balance to reserve',))]
fn test_reserve_balance_insufficient() {
    let (micro_payment_manager, _, _, _, user) = setup();
    
    // Try to reserve balance without any streams - should panic
    micro_payment_manager.reserve_balance(user, 1000_u256);
}

#[test]
fn test_get_payment_history() {
    let (micro_payment_manager, stream_manager, _, creator, user) = setup();
    
    // Register content
    set_caller_address(creator);
    micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
    
    // Create stream for user
    let stream_id = create_test_stream(stream_manager, user, creator);
    
    // Advance time to accumulate balance
    set_block_timestamp(get_current_time() + 1000);
    
    // Process multiple payments
    set_caller_address(user);
    let payment_id1 = micro_payment_manager.process_micro_payment(CONTENT_ID, stream_id);
    
    // Advance time and make another payment
    set_block_timestamp(get_current_time() + 1000);
    let payment_id2 = micro_payment_manager.process_micro_payment(CONTENT_ID, stream_id);
    
    // Get payment history
    let payments = micro_payment_manager.get_payment_history(user, 10);
    assert(payments.len() == 2, 'Should have 2 payments');
    
    // Verify payment details
    let payment1 = *payments.at(0);
    let payment2 = *payments.at(1);
    
    assert(payment1.id == payment_id1, 'Wrong payment ID 1');
    assert(payment2.id == payment_id2, 'Wrong payment ID 2');
    assert(payment1.payer == user, 'Wrong payer 1');
    assert(payment2.payer == user, 'Wrong payer 2');
    assert(payment1.content_creator == creator, 'Wrong creator 1');
    assert(payment2.content_creator == creator, 'Wrong creator 2');
}

#[test]
fn test_get_creator_content() {
    let (micro_payment_manager, _, _, creator, _) = setup();
    
    set_caller_address(creator);
    
    // Register multiple content items
    let content_id1 = 1_u256;
    let content_id2 = 2_u256;
    let content_id3 = 3_u256;
    
    micro_payment_manager.register_content(content_id1, PRICE_PER_ACCESS);
    micro_payment_manager.register_content(content_id2, PRICE_PER_ACCESS * 2);
    micro_payment_manager.register_content(content_id3, PRICE_PER_ACCESS * 3);
    
    // Get creator's content
    let content_ids = micro_payment_manager.get_creator_content(creator);
    assert(content_ids.len() == 3, 'Should have 3 content items');
    
    // Verify content IDs
    assert(*content_ids.at(0) == content_id1, 'Wrong content ID 1');
    assert(*content_ids.at(1) == content_id2, 'Wrong content ID 2');
    assert(*content_ids.at(2) == content_id3, 'Wrong content ID 3');
}

#[test]
fn test_calculate_available_balance() {
    let (micro_payment_manager, stream_manager, _, creator, user) = setup();
    
    // Create multiple streams for user
    let stream_id1 = create_test_stream(stream_manager, user, creator);
    let stream_id2 = create_test_stream(stream_manager, user, creator);
    
    // Advance time to accumulate balance
    set_block_timestamp(get_current_time() + 1000);
    
    // Calculate available balance
    let balance = micro_payment_manager.calculate_available_balance(user);
    
    // Should be sum of balances from both streams
    let expected_balance = STREAM_RATE * 1000 * 2; // 2 streams, 1000 seconds each
    assert(balance == expected_balance, 'Available balance incorrect');
}

#[test]
fn test_multiple_micro_payments_update_statistics() {
    let (micro_payment_manager, stream_manager, _, creator, user) = setup();
    
    // Register content
    set_caller_address(creator);
    micro_payment_manager.register_content(CONTENT_ID, PRICE_PER_ACCESS);
    
    // Create stream for user
    let stream_id = create_test_stream(stream_manager, user, creator);
    
    // Advance time to accumulate sufficient balance
    set_block_timestamp(get_current_time() + 5000);
    
    // Process multiple payments
    set_caller_address(user);
    let num_payments = 3;
    let mut i = 0;
    while i < num_payments {
        micro_payment_manager.process_micro_payment(CONTENT_ID, stream_id);
        i += 1;
    };
    
    // Verify content statistics
    let content = micro_payment_manager.get_content_info(CONTENT_ID);
    assert(content.total_accesses == num_payments.into(), 'Wrong access count');
    assert(content.total_revenue == PRICE_PER_ACCESS * num_payments.into(), 'Wrong revenue');
}