use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use starknet::testing::{set_caller_address, set_block_timestamp};

use bitflow::contracts::error_handler::{ErrorHandler, IErrorHandlerDispatcher, IErrorHandlerDispatcherTrait};
use bitflow::types::{BitFlowError, ErrorSeverity, ErrorContext, RecoveryAction, RecoveryPlan, SystemHealthStatus};

fn deploy_error_handler() -> IErrorHandlerDispatcher {
    let owner = contract_address_const::<'owner'>();
    let contract = ErrorHandler::deploy(owner).unwrap();
    IErrorHandlerDispatcher { contract_address: contract }
}

#[test]
fn test_error_reporting() {
    let error_handler = deploy_error_handler();
    let caller = contract_address_const::<'caller'>();
    set_caller_address(caller);
    set_block_timestamp(1000);
    
    // Report an error
    let error_id = error_handler.report_error(
        BitFlowError::StreamNotFound,
        ErrorSeverity::Medium,
        'test_data'
    );
    
    assert(error_id == 1, 'Wrong error ID');
    
    // Get error context
    let error_context = error_handler.get_error_context(error_id);
    assert(error_context.error_type == BitFlowError::StreamNotFound, 'Wrong error type');
    assert(error_context.severity == ErrorSeverity::Medium, 'Wrong severity');
    assert(error_context.timestamp == 1000, 'Wrong timestamp');
    assert(error_context.caller == caller, 'Wrong caller');
    assert(error_context.additional_data == 'test_data', 'Wrong additional data');
}

#[test]
fn test_error_count_tracking() {
    let error_handler = deploy_error_handler();
    let caller = contract_address_const::<'caller'>();
    set_caller_address(caller);
    
    // Report multiple errors of same type
    error_handler.report_error(BitFlowError::BridgeFailure, ErrorSeverity::High, 0);
    error_handler.report_error(BitFlowError::BridgeFailure, ErrorSeverity::High, 0);
    error_handler.report_error(BitFlowError::StreamNotFound, ErrorSeverity::Medium, 0);
    
    // Check error counts
    let bridge_count = error_handler.get_error_count_by_type(BitFlowError::BridgeFailure);
    let stream_count = error_handler.get_error_count_by_type(BitFlowError::StreamNotFound);
    
    assert(bridge_count == 2, 'Wrong bridge error count');
    assert(stream_count == 1, 'Wrong stream error count');
}

#[test]
fn test_system_health_monitoring() {
    let error_handler = deploy_error_handler();
    let caller = contract_address_const::<'caller'>();
    set_caller_address(caller);
    
    // Initially healthy
    let health = error_handler.get_system_health_status();
    assert(matches!(health, SystemHealthStatus::Healthy), 'Should be healthy initially');
    
    // Report critical error
    error_handler.report_error(BitFlowError::SystemOverloaded, ErrorSeverity::Critical, 0);
    
    // Health should change to critical
    let health = error_handler.get_system_health_status();
    assert(matches!(health, SystemHealthStatus::Critical), 'Should be critical after error');
}

#[test]
fn test_emergency_pause() {
    let error_handler = deploy_error_handler();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Initially not paused
    assert(!error_handler.is_emergency_paused(), 'Should not be paused initially');
    
    // Trigger emergency pause
    let success = error_handler.trigger_emergency_pause('test_reason');
    assert(success, 'Emergency pause should succeed');
    assert(error_handler.is_emergency_paused(), 'Should be paused after trigger');
    
    // Lift emergency pause
    let success = error_handler.lift_emergency_pause();
    assert(success, 'Lift pause should succeed');
    assert(!error_handler.is_emergency_paused(), 'Should not be paused after lift');
}

#[test]
#[should_panic(expected: ('Only owner can call',))]
fn test_emergency_pause_unauthorized() {
    let error_handler = deploy_error_handler();
    let unauthorized = contract_address_const::<'unauthorized'>();
    set_caller_address(unauthorized);
    
    // Should fail for non-owner
    error_handler.lift_emergency_pause();
}

#[test]
fn test_recovery_plan_management() {
    let error_handler = deploy_error_handler();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Create custom recovery plan
    let recovery_plan = RecoveryPlan {
        action: RecoveryAction::Retry,
        max_retries: 5,
        retry_delay: 120,
        escalation_threshold: 3,
        requires_manual_approval: false,
    };
    
    // Update recovery plan
    let success = error_handler.update_recovery_plan(BitFlowError::BridgeTimeout, recovery_plan);
    assert(success, 'Recovery plan update should succeed');
    
    // Get recovery plan
    let retrieved_plan = error_handler.get_recovery_plan(BitFlowError::BridgeTimeout);
    assert(matches!(retrieved_plan.action, RecoveryAction::Retry), 'Wrong recovery action');
    assert(retrieved_plan.max_retries == 5, 'Wrong max retries');
    assert(retrieved_plan.retry_delay == 120, 'Wrong retry delay');
}

#[test]
fn test_error_threshold() {
    let error_handler = deploy_error_handler();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Set error threshold
    let success = error_handler.set_error_threshold(BitFlowError::BridgeFailure, 3);
    assert(success, 'Threshold setting should succeed');
    
    // Report errors up to threshold
    let caller = contract_address_const::<'caller'>();
    set_caller_address(caller);
    
    error_handler.report_error(BitFlowError::BridgeFailure, ErrorSeverity::High, 0);
    error_handler.report_error(BitFlowError::BridgeFailure, ErrorSeverity::High, 0);
    
    // Should not be paused yet
    assert(!error_handler.is_emergency_paused(), 'Should not be paused before threshold');
    
    // Report one more error to exceed threshold
    error_handler.report_error(BitFlowError::BridgeFailure, ErrorSeverity::High, 0);
    
    // Should trigger emergency pause
    assert(error_handler.is_emergency_paused(), 'Should be paused after threshold exceeded');
}

#[test]
fn test_recent_errors_retrieval() {
    let error_handler = deploy_error_handler();
    let caller = contract_address_const::<'caller'>();
    set_caller_address(caller);
    
    // Report several errors
    error_handler.report_error(BitFlowError::StreamNotFound, ErrorSeverity::Medium, 'error1');
    error_handler.report_error(BitFlowError::BridgeFailure, ErrorSeverity::High, 'error2');
    error_handler.report_error(BitFlowError::YieldProtocolError, ErrorSeverity::High, 'error3');
    
    // Get recent errors
    let recent_errors = error_handler.get_recent_errors(2);
    assert(recent_errors.len() == 2, 'Wrong number of recent errors');
    
    // Should get the most recent errors
    let error1 = recent_errors.at(0);
    let error2 = recent_errors.at(1);
    
    assert(error1.additional_data == 'error2', 'Wrong first recent error');
    assert(error2.additional_data == 'error3', 'Wrong second recent error');
}

#[test]
fn test_error_escalation() {
    let error_handler = deploy_error_handler();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Report a medium severity error
    let caller = contract_address_const::<'caller'>();
    set_caller_address(caller);
    
    let error_id = error_handler.report_error(
        BitFlowError::StreamNotFound,
        ErrorSeverity::Medium,
        0
    );
    
    // Escalate the error
    set_caller_address(owner);
    let success = error_handler.escalate_error(error_id);
    assert(success, 'Error escalation should succeed');
}

#[test]
fn test_failed_operation_retry() {
    let error_handler = deploy_error_handler();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Set up recovery plan with retries
    let recovery_plan = RecoveryPlan {
        action: RecoveryAction::Retry,
        max_retries: 3,
        retry_delay: 60,
        escalation_threshold: 5,
        requires_manual_approval: false,
    };
    
    error_handler.update_recovery_plan(BitFlowError::BridgeTimeout, recovery_plan);
    
    // Report error that creates failed operation
    let caller = contract_address_const::<'caller'>();
    set_caller_address(caller);
    
    let error_id = error_handler.report_error(
        BitFlowError::BridgeTimeout,
        ErrorSeverity::High,
        0
    );
    
    // Try to retry operation (operation_id would be 1 for first operation)
    set_caller_address(owner);
    let success = error_handler.retry_failed_operation(1);
    assert(success, 'Operation retry should succeed');
}

#[test]
fn test_error_handling_workflow() {
    let error_handler = deploy_error_handler();
    let owner = contract_address_const::<'owner'>();
    let caller = contract_address_const::<'caller'>();
    
    // Set up custom recovery plan
    set_caller_address(owner);
    let recovery_plan = RecoveryPlan {
        action: RecoveryAction::Pause,
        max_retries: 2,
        retry_delay: 30,
        escalation_threshold: 3,
        requires_manual_approval: false,
    };
    error_handler.update_recovery_plan(BitFlowError::YieldProtocolError, recovery_plan);
    
    // Report error
    set_caller_address(caller);
    let error_id = error_handler.report_error(
        BitFlowError::YieldProtocolError,
        ErrorSeverity::High,
        'yield_failure'
    );
    
    // Handle the error
    set_caller_address(owner);
    let success = error_handler.handle_error(error_id);
    assert(success, 'Error handling should succeed');
    
    // Initiate recovery
    let success = error_handler.initiate_recovery(error_id);
    assert(success, 'Recovery initiation should succeed');
}

#[test]
#[should_panic(expected: ('Error not found',))]
fn test_get_nonexistent_error() {
    let error_handler = deploy_error_handler();
    
    // Try to get non-existent error
    error_handler.get_error_context(999);
}

#[test]
fn test_multiple_error_types() {
    let error_handler = deploy_error_handler();
    let caller = contract_address_const::<'caller'>();
    set_caller_address(caller);
    
    // Report different types of errors
    error_handler.report_error(BitFlowError::InsufficientBalance, ErrorSeverity::Medium, 0);
    error_handler.report_error(BitFlowError::UnauthorizedAccess, ErrorSeverity::Medium, 0);
    error_handler.report_error(BitFlowError::InvalidParameters, ErrorSeverity::Low, 0);
    error_handler.report_error(BitFlowError::SystemOverloaded, ErrorSeverity::Critical, 0);
    
    // Check individual counts
    assert(error_handler.get_error_count_by_type(BitFlowError::InsufficientBalance) == 1, 'Wrong balance error count');
    assert(error_handler.get_error_count_by_type(BitFlowError::UnauthorizedAccess) == 1, 'Wrong access error count');
    assert(error_handler.get_error_count_by_type(BitFlowError::InvalidParameters) == 1, 'Wrong param error count');
    assert(error_handler.get_error_count_by_type(BitFlowError::SystemOverloaded) == 1, 'Wrong system error count');
    
    // System should be in critical state due to critical error
    let health = error_handler.get_system_health_status();
    assert(matches!(health, SystemHealthStatus::Critical), 'System should be critical');
}