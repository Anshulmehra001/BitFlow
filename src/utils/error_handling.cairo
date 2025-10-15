use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use crate::types::{BitFlowError, ErrorSeverity, ErrorContext, RecoveryAction};

/// Result type for operations that can fail with BitFlowError
#[derive(Drop, Serde)]
pub enum BitFlowResult<T> {
    Ok: T,
    Err: BitFlowError,
}

/// Trait for error handling utilities
pub trait ErrorHandlingTrait<T> {
    fn unwrap(self: BitFlowResult<T>) -> T;
    fn unwrap_or(self: BitFlowResult<T>, default: T) -> T;
    fn is_ok(self: @BitFlowResult<T>) -> bool;
    fn is_err(self: @BitFlowResult<T>) -> bool;
    fn map_err<U>(self: BitFlowResult<T>, f: fn(BitFlowError) -> U) -> BitFlowResult<T>;
}

impl ErrorHandlingImpl<T> of ErrorHandlingTrait<T> {
    fn unwrap(self: BitFlowResult<T>) -> T {
        match self {
            BitFlowResult::Ok(value) => value,
            BitFlowResult::Err(error) => {
                panic!("BitFlowResult unwrap failed: {:?}", error);
            },
        }
    }

    fn unwrap_or(self: BitFlowResult<T>, default: T) -> T {
        match self {
            BitFlowResult::Ok(value) => value,
            BitFlowResult::Err(_) => default,
        }
    }

    fn is_ok(self: @BitFlowResult<T>) -> bool {
        match self {
            BitFlowResult::Ok(_) => true,
            BitFlowResult::Err(_) => false,
        }
    }

    fn is_err(self: @BitFlowResult<T>) -> bool {
        match self {
            BitFlowResult::Ok(_) => false,
            BitFlowResult::Err(_) => true,
        }
    }

    fn map_err<U>(self: BitFlowResult<T>, f: fn(BitFlowError) -> U) -> BitFlowResult<T> {
        match self {
            BitFlowResult::Ok(value) => BitFlowResult::Ok(value),
            BitFlowResult::Err(error) => {
                f(error);
                BitFlowResult::Err(error)
            },
        }
    }
}

/// Validates stream parameters and returns appropriate error
pub fn validate_stream_parameters(
    recipient: ContractAddress,
    amount: u256,
    rate: u256,
    duration: u64
) -> BitFlowResult<()> {
    // Check for zero address
    if recipient.is_zero() {
        return BitFlowResult::Err(BitFlowError::InvalidAddress);
    }
    
    // Check for zero amount
    if amount == 0 {
        return BitFlowResult::Err(BitFlowError::ZeroAmount);
    }
    
    // Check for zero rate
    if rate == 0 {
        return BitFlowResult::Err(BitFlowError::InvalidRate);
    }
    
    // Check for zero duration
    if duration == 0 {
        return BitFlowResult::Err(BitFlowError::InvalidDuration);
    }
    
    // Check if rate * duration exceeds amount (would never complete)
    if rate * duration.into() > amount {
        return BitFlowResult::Err(BitFlowError::InvalidParameters);
    }
    
    BitFlowResult::Ok(())
}

/// Validates bridge transaction parameters
pub fn validate_bridge_parameters(
    amount: u256,
    minimum_amount: u256,
    recipient: ContractAddress
) -> BitFlowResult<()> {
    if recipient.is_zero() {
        return BitFlowResult::Err(BitFlowError::InvalidAddress);
    }
    
    if amount == 0 {
        return BitFlowResult::Err(BitFlowError::ZeroAmount);
    }
    
    if amount < minimum_amount {
        return BitFlowResult::Err(BitFlowError::InvalidParameters);
    }
    
    BitFlowResult::Ok(())
}

/// Validates yield operation parameters
pub fn validate_yield_parameters(
    amount: u256,
    protocol_address: ContractAddress
) -> BitFlowResult<()> {
    if protocol_address.is_zero() {
        return BitFlowResult::Err(BitFlowError::InvalidAddress);
    }
    
    if amount == 0 {
        return BitFlowResult::Err(BitFlowError::ZeroAmount);
    }
    
    BitFlowResult::Ok(())
}

/// Determines error severity based on error type
pub fn get_error_severity(error_type: BitFlowError) -> ErrorSeverity {
    match error_type {
        // Low severity - warnings and minor issues
        BitFlowError::InvalidParameters |
        BitFlowError::ZeroAmount |
        BitFlowError::InvalidAddress |
        BitFlowError::InvalidRate |
        BitFlowError::InvalidDuration => ErrorSeverity::Low,
        
        // Medium severity - operation failures
        BitFlowError::InsufficientBalance |
        BitFlowError::StreamNotFound |
        BitFlowError::UnauthorizedAccess |
        BitFlowError::StreamNotActive |
        BitFlowError::MicroPaymentFailed |
        BitFlowError::ContentNotFound => ErrorSeverity::Medium,
        
        // High severity - system component failures
        BitFlowError::BridgeFailure |
        BitFlowError::YieldProtocolError |
        BitFlowError::BridgeTimeout |
        BitFlowError::YieldProtocolUnavailable => ErrorSeverity::High,
        
        // Critical severity - system-wide failures
        BitFlowError::SystemOverloaded |
        BitFlowError::EmergencyPauseActive |
        BitFlowError::RecoveryFailed |
        BitFlowError::StorageError => ErrorSeverity::Critical,
        
        // Default to medium for unspecified errors
        _ => ErrorSeverity::Medium,
    }
}

/// Creates error context for reporting
pub fn create_error_context(
    error_type: BitFlowError,
    additional_data: felt252
) -> ErrorContext {
    ErrorContext {
        error_type,
        severity: get_error_severity(error_type),
        timestamp: get_block_timestamp(),
        contract_address: get_caller_address(),
        caller: get_caller_address(),
        additional_data,
    }
}

/// Checks if an error is recoverable
pub fn is_recoverable_error(error_type: BitFlowError) -> bool {
    match error_type {
        // Recoverable errors
        BitFlowError::InsufficientBalance |
        BitFlowError::BridgeTimeout |
        BitFlowError::YieldProtocolUnavailable |
        BitFlowError::SystemOverloaded |
        BitFlowError::InsufficientGas => true,
        
        // Non-recoverable errors
        BitFlowError::InvalidParameters |
        BitFlowError::InvalidAddress |
        BitFlowError::ZeroAmount |
        BitFlowError::UnauthorizedAccess |
        BitFlowError::StreamNotFound => false,
        
        // Default to recoverable for safety
        _ => true,
    }
}

/// Gets recommended recovery action for error type
pub fn get_recommended_recovery_action(error_type: BitFlowError) -> RecoveryAction {
    match error_type {
        // Retry for temporary failures
        BitFlowError::InsufficientGas |
        BitFlowError::SystemOverloaded |
        BitFlowError::BridgeTimeout => RecoveryAction::Retry,
        
        // Pause for protocol failures
        BitFlowError::BridgeFailure |
        BitFlowError::YieldProtocolError => RecoveryAction::Pause,
        
        // Rollback for state inconsistencies
        BitFlowError::StorageError |
        BitFlowError::RecoveryFailed => RecoveryAction::Rollback,
        
        // Emergency stop for critical failures
        BitFlowError::EmergencyPauseActive => RecoveryAction::EmergencyStop,
        
        // Manual intervention for complex issues
        BitFlowError::UnauthorizedAccess |
        BitFlowError::InvalidParameters => RecoveryAction::ManualIntervention,
        
        // No action for informational errors
        _ => RecoveryAction::NoAction,
    }
}

/// Calculates retry delay based on attempt count
pub fn calculate_retry_delay(attempt: u8, base_delay: u64) -> u64 {
    // Exponential backoff with jitter
    let exponential_delay = base_delay * (2_u64.pow(attempt.into()));
    let max_delay = 3600; // 1 hour maximum
    
    if exponential_delay > max_delay {
        max_delay
    } else {
        exponential_delay
    }
}

/// Checks if error should trigger emergency pause
pub fn should_trigger_emergency_pause(
    error_type: BitFlowError,
    error_count: u256,
    time_window: u64
) -> bool {
    match error_type {
        // Always trigger for critical errors
        BitFlowError::SystemOverloaded |
        BitFlowError::StorageError |
        BitFlowError::RecoveryFailed => true,
        
        // Trigger if too many bridge failures
        BitFlowError::BridgeFailure => error_count > 5,
        
        // Trigger if too many yield failures
        BitFlowError::YieldProtocolError => error_count > 10,
        
        // Don't trigger for minor errors
        _ => false,
    }
}

/// Formats error message for logging
pub fn format_error_message(error_type: BitFlowError, additional_data: felt252) -> Array<felt252> {
    let mut message = ArrayTrait::new();
    
    // Add error type identifier
    message.append('BitFlow Error: ');
    
    // Add specific error message
    let error_msg = match error_type {
        BitFlowError::InsufficientBalance => 'Insufficient balance',
        BitFlowError::StreamNotFound => 'Stream not found',
        BitFlowError::UnauthorizedAccess => 'Unauthorized access',
        BitFlowError::BridgeFailure => 'Bridge operation failed',
        BitFlowError::YieldProtocolError => 'Yield protocol error',
        BitFlowError::InvalidParameters => 'Invalid parameters',
        BitFlowError::SystemOverloaded => 'System overloaded',
        BitFlowError::EmergencyPauseActive => 'Emergency pause active',
        _ => 'Unknown error',
    };
    
    message.append(error_msg);
    
    // Add additional data if provided
    if additional_data != 0 {
        message.append(' - Data: ');
        message.append(additional_data);
    }
    
    message
}