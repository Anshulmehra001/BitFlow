use starknet::{ContractAddress, contract_address_const};
use starknet::testing::{set_caller_address, set_block_timestamp};

use bitflow::utils::error_handling::{
    BitFlowResult, ErrorHandlingTrait, validate_stream_parameters, validate_bridge_parameters,
    validate_yield_parameters, get_error_severity, create_error_context, is_recoverable_error,
    get_recommended_recovery_action, calculate_retry_delay, should_trigger_emergency_pause,
    format_error_message
};
use bitflow::types::{BitFlowError, ErrorSeverity, RecoveryAction};

#[test]
fn test_bitflow_result_ok() {
    let result: BitFlowResult<u256> = BitFlowResult::Ok(42);
    
    assert(result.is_ok(), 'Should be Ok');
    assert(!result.is_err(), 'Should not be Err');
    
    let value = result.unwrap();
    assert(value == 42, 'Wrong unwrapped value');
}

#[test]
fn test_bitflow_result_err() {
    let result: BitFlowResult<u256> = BitFlowResult::Err(BitFlowError::InsufficientBalance);
    
    assert(!result.is_ok(), 'Should not be Ok');
    assert(result.is_err(), 'Should be Err');
    
    let default_value = result.unwrap_or(100);
    assert(default_value == 100, 'Wrong default value');
}

#[test]
#[should_panic]
fn test_bitflow_result_unwrap_panic() {
    let result: BitFlowResult<u256> = BitFlowResult::Err(BitFlowError::StreamNotFound);
    result.unwrap(); // Should panic
}

#[test]
fn test_validate_stream_parameters_success() {
    let recipient = contract_address_const::<'recipient'>();
    let result = validate_stream_parameters(recipient, 1000, 10, 100);
    
    assert(result.is_ok(), 'Validation should succeed');
}

#[test]
fn test_validate_stream_parameters_zero_address() {
    let recipient = contract_address_const::<0>();
    let result = validate_stream_parameters(recipient, 1000, 10, 100);
    
    assert(result.is_err(), 'Should fail for zero address');
    match result {
        BitFlowResult::Err(error) => assert(error == BitFlowError::InvalidAddress, 'Wrong error type'),
        BitFlowResult::Ok(_) => panic!("Should not be Ok"),
    }
}

#[test]
fn test_validate_stream_parameters_zero_amount() {
    let recipient = contract_address_const::<'recipient'>();
    let result = validate_stream_parameters(recipient, 0, 10, 100);
    
    assert(result.is_err(), 'Should fail for zero amount');
    match result {
        BitFlowResult::Err(error) => assert(error == BitFlowError::ZeroAmount, 'Wrong error type'),
        BitFlowResult::Ok(_) => panic!("Should not be Ok"),
    }
}

#[test]
fn test_validate_stream_parameters_zero_rate() {
    let recipient = contract_address_const::<'recipient'>();
    let result = validate_stream_parameters(recipient, 1000, 0, 100);
    
    assert(result.is_err(), 'Should fail for zero rate');
    match result {
        BitFlowResult::Err(error) => assert(error == BitFlowError::InvalidRate, 'Wrong error type'),
        BitFlowResult::Ok(_) => panic!("Should not be Ok"),
    }
}

#[test]
fn test_validate_stream_parameters_zero_duration() {
    let recipient = contract_address_const::<'recipient'>();
    let result = validate_stream_parameters(recipient, 1000, 10, 0);
    
    assert(result.is_err(), 'Should fail for zero duration');
    match result {
        BitFlowResult::Err(error) => assert(error == BitFlowError::InvalidDuration, 'Wrong error type'),
        BitFlowResult::Ok(_) => panic!("Should not be Ok"),
    }
}

#[test]
fn test_validate_stream_parameters_invalid_rate_duration() {
    let recipient = contract_address_const::<'recipient'>();
    // Rate * duration > amount (10 * 200 = 2000 > 1000)
    let result = validate_stream_parameters(recipient, 1000, 10, 200);
    
    assert(result.is_err(), 'Should fail for invalid rate/duration');
    match result {
        BitFlowResult::Err(error) => assert(error == BitFlowError::InvalidParameters, 'Wrong error type'),
        BitFlowResult::Ok(_) => panic!("Should not be Ok"),
    }
}

#[test]
fn test_validate_bridge_parameters_success() {
    let recipient = contract_address_const::<'recipient'>();
    let result = validate_bridge_parameters(1000, 100, recipient);
    
    assert(result.is_ok(), 'Bridge validation should succeed');
}

#[test]
fn test_validate_bridge_parameters_below_minimum() {
    let recipient = contract_address_const::<'recipient'>();
    let result = validate_bridge_parameters(50, 100, recipient);
    
    assert(result.is_err(), 'Should fail for amount below minimum');
    match result {
        BitFlowResult::Err(error) => assert(error == BitFlowError::InvalidParameters, 'Wrong error type'),
        BitFlowResult::Ok(_) => panic!("Should not be Ok"),
    }
}

#[test]
fn test_validate_yield_parameters_success() {
    let protocol = contract_address_const::<'protocol'>();
    let result = validate_yield_parameters(1000, protocol);
    
    assert(result.is_ok(), 'Yield validation should succeed');
}

#[test]
fn test_validate_yield_parameters_zero_protocol() {
    let protocol = contract_address_const::<0>();
    let result = validate_yield_parameters(1000, protocol);
    
    assert(result.is_err(), 'Should fail for zero protocol address');
    match result {
        BitFlowResult::Err(error) => assert(error == BitFlowError::InvalidAddress, 'Wrong error type'),
        BitFlowResult::Ok(_) => panic!("Should not be Ok"),
    }
}

#[test]
fn test_get_error_severity() {
    // Test low severity errors
    let severity = get_error_severity(BitFlowError::InvalidParameters);
    assert(matches!(severity, ErrorSeverity::Low), 'Should be low severity');
    
    let severity = get_error_severity(BitFlowError::ZeroAmount);
    assert(matches!(severity, ErrorSeverity::Low), 'Should be low severity');
    
    // Test medium severity errors
    let severity = get_error_severity(BitFlowError::InsufficientBalance);
    assert(matches!(severity, ErrorSeverity::Medium), 'Should be medium severity');
    
    let severity = get_error_severity(BitFlowError::StreamNotFound);
    assert(matches!(severity, ErrorSeverity::Medium), 'Should be medium severity');
    
    // Test high severity errors
    let severity = get_error_severity(BitFlowError::BridgeFailure);
    assert(matches!(severity, ErrorSeverity::High), 'Should be high severity');
    
    let severity = get_error_severity(BitFlowError::YieldProtocolError);
    assert(matches!(severity, ErrorSeverity::High), 'Should be high severity');
    
    // Test critical severity errors
    let severity = get_error_severity(BitFlowError::SystemOverloaded);
    assert(matches!(severity, ErrorSeverity::Critical), 'Should be critical severity');
    
    let severity = get_error_severity(BitFlowError::StorageError);
    assert(matches!(severity, ErrorSeverity::Critical), 'Should be critical severity');
}

#[test]
fn test_create_error_context() {
    let caller = contract_address_const::<'caller'>();
    set_caller_address(caller);
    set_block_timestamp(1000);
    
    let context = create_error_context(BitFlowError::StreamNotFound, 'test_data');
    
    assert(context.error_type == BitFlowError::StreamNotFound, 'Wrong error type');
    assert(matches!(context.severity, ErrorSeverity::Medium), 'Wrong severity');
    assert(context.timestamp == 1000, 'Wrong timestamp');
    assert(context.caller == caller, 'Wrong caller');
    assert(context.additional_data == 'test_data', 'Wrong additional data');
}

#[test]
fn test_is_recoverable_error() {
    // Test recoverable errors
    assert(is_recoverable_error(BitFlowError::InsufficientBalance), 'Should be recoverable');
    assert(is_recoverable_error(BitFlowError::BridgeTimeout), 'Should be recoverable');
    assert(is_recoverable_error(BitFlowError::SystemOverloaded), 'Should be recoverable');
    
    // Test non-recoverable errors
    assert(!is_recoverable_error(BitFlowError::InvalidParameters), 'Should not be recoverable');
    assert(!is_recoverable_error(BitFlowError::InvalidAddress), 'Should not be recoverable');
    assert(!is_recoverable_error(BitFlowError::UnauthorizedAccess), 'Should not be recoverable');
}

#[test]
fn test_get_recommended_recovery_action() {
    // Test retry actions
    let action = get_recommended_recovery_action(BitFlowError::InsufficientGas);
    assert(matches!(action, RecoveryAction::Retry), 'Should recommend retry');
    
    let action = get_recommended_recovery_action(BitFlowError::SystemOverloaded);
    assert(matches!(action, RecoveryAction::Retry), 'Should recommend retry');
    
    // Test pause actions
    let action = get_recommended_recovery_action(BitFlowError::BridgeFailure);
    assert(matches!(action, RecoveryAction::Pause), 'Should recommend pause');
    
    let action = get_recommended_recovery_action(BitFlowError::YieldProtocolError);
    assert(matches!(action, RecoveryAction::Pause), 'Should recommend pause');
    
    // Test rollback actions
    let action = get_recommended_recovery_action(BitFlowError::StorageError);
    assert(matches!(action, RecoveryAction::Rollback), 'Should recommend rollback');
    
    // Test emergency stop actions
    let action = get_recommended_recovery_action(BitFlowError::EmergencyPauseActive);
    assert(matches!(action, RecoveryAction::EmergencyStop), 'Should recommend emergency stop');
    
    // Test manual intervention actions
    let action = get_recommended_recovery_action(BitFlowError::UnauthorizedAccess);
    assert(matches!(action, RecoveryAction::ManualIntervention), 'Should recommend manual intervention');
}

#[test]
fn test_calculate_retry_delay() {
    // Test exponential backoff
    let delay1 = calculate_retry_delay(0, 60); // First attempt
    assert(delay1 == 60, 'Wrong delay for first attempt');
    
    let delay2 = calculate_retry_delay(1, 60); // Second attempt
    assert(delay2 == 120, 'Wrong delay for second attempt');
    
    let delay3 = calculate_retry_delay(2, 60); // Third attempt
    assert(delay3 == 240, 'Wrong delay for third attempt');
    
    // Test maximum delay cap
    let delay_max = calculate_retry_delay(10, 60); // Many attempts
    assert(delay_max == 3600, 'Should cap at maximum delay');
}

#[test]
fn test_should_trigger_emergency_pause() {
    // Test critical errors always trigger
    assert(
        should_trigger_emergency_pause(BitFlowError::SystemOverloaded, 1, 3600),
        'Critical error should trigger pause'
    );
    
    assert(
        should_trigger_emergency_pause(BitFlowError::StorageError, 1, 3600),
        'Storage error should trigger pause'
    );
    
    // Test bridge failures with count threshold
    assert(
        should_trigger_emergency_pause(BitFlowError::BridgeFailure, 6, 3600),
        'Many bridge failures should trigger pause'
    );
    
    assert(
        !should_trigger_emergency_pause(BitFlowError::BridgeFailure, 3, 3600),
        'Few bridge failures should not trigger pause'
    );
    
    // Test yield failures with count threshold
    assert(
        should_trigger_emergency_pause(BitFlowError::YieldProtocolError, 11, 3600),
        'Many yield failures should trigger pause'
    );
    
    assert(
        !should_trigger_emergency_pause(BitFlowError::YieldProtocolError, 5, 3600),
        'Few yield failures should not trigger pause'
    );
    
    // Test minor errors don't trigger
    assert(
        !should_trigger_emergency_pause(BitFlowError::InvalidParameters, 100, 3600),
        'Minor errors should not trigger pause'
    );
}

#[test]
fn test_format_error_message() {
    let message = format_error_message(BitFlowError::StreamNotFound, 'stream_123');
    
    assert(message.len() >= 3, 'Message should have multiple parts');
    assert(*message.at(0) == 'BitFlow Error: ', 'Wrong message prefix');
    assert(*message.at(1) == 'Stream not found', 'Wrong error message');
    assert(*message.at(2) == ' - Data: ', 'Wrong data separator');
    assert(*message.at(3) == 'stream_123', 'Wrong additional data');
}

#[test]
fn test_format_error_message_no_data() {
    let message = format_error_message(BitFlowError::InsufficientBalance, 0);
    
    assert(message.len() == 2, 'Message should have two parts');
    assert(*message.at(0) == 'BitFlow Error: ', 'Wrong message prefix');
    assert(*message.at(1) == 'Insufficient balance', 'Wrong error message');
}

#[test]
fn test_error_handling_trait_map_err() {
    let result: BitFlowResult<u256> = BitFlowResult::Err(BitFlowError::StreamNotFound);
    
    let mut error_logged = false;
    let mapped_result = result.map_err(|_error| {
        error_logged = true;
    });
    
    assert(error_logged, 'Error callback should be called');
    assert(mapped_result.is_err(), 'Result should still be error');
}