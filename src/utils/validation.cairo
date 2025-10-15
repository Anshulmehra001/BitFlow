use starknet::ContractAddress;
use crate::types::{PaymentStream, Subscription, YieldPosition, SubscriptionStatus, BitFlowError};

/// Validates stream creation parameters
/// @param recipient The recipient address
/// @param amount The total amount
/// @param rate The rate per second
/// @param duration The stream duration
/// @return result Result indicating success or specific error
pub fn validate_stream_parameters(
    recipient: ContractAddress,
    amount: u256,
    rate: u256,
    duration: u64
) -> Result<(), BitFlowError> {
    // Check for zero address
    if recipient.is_zero() {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    // Check for zero amount
    if amount == 0 {
        return Result::Err(BitFlowError::ZeroAmount);
    }
    
    // Check for zero rate
    if rate == 0 {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    // Check for zero duration
    if duration == 0 {
        return Result::Err(BitFlowError::InvalidTimeRange);
    }
    
    // Validate that rate * duration doesn't exceed amount significantly
    let calculated_total = rate * duration.into();
    if calculated_total > amount * 2 {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    Result::Ok(())
}

/// Validates that a stream exists and is active
/// @param stream The PaymentStream to validate
/// @return result Result indicating success or specific error
pub fn validate_stream_active(stream: PaymentStream) -> Result<(), BitFlowError> {
    if stream.id == 0 {
        return Result::Err(BitFlowError::StreamNotFound);
    }
    
    if !stream.is_active {
        return Result::Err(BitFlowError::StreamNotActive);
    }
    
    Result::Ok(())
}

/// Validates that an address has permission to perform an action on a stream
/// @param stream The PaymentStream to check
/// @param caller The address attempting the action
/// @param require_sender Whether the caller must be the sender (true) or recipient (false)
/// @return result Result indicating success or specific error
pub fn validate_stream_permission(
    stream: PaymentStream,
    caller: ContractAddress,
    require_sender: bool
) -> Result<(), BitFlowError> {
    if require_sender {
        if caller != stream.sender {
            return Result::Err(BitFlowError::UnauthorizedAccess);
        }
    } else {
        if caller != stream.recipient {
            return Result::Err(BitFlowError::UnauthorizedAccess);
        }
    }
    
    Result::Ok(())
}

/// Validates subscription parameters
/// @param price The subscription price
/// @param interval The billing interval
/// @param max_subscribers Maximum number of subscribers
/// @return result Result indicating success or specific error
pub fn validate_subscription_parameters(
    price: u256,
    interval: u64,
    max_subscribers: u32
) -> Result<(), BitFlowError> {
    if price == 0 {
        return Result::Err(BitFlowError::ZeroAmount);
    }
    
    if interval == 0 {
        return Result::Err(BitFlowError::InvalidTimeRange);
    }
    
    if max_subscribers == 0 {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    Result::Ok(())
}

/// Validates yield staking parameters
/// @param amount The amount to stake
/// @param protocol The protocol address
/// @param min_stake_amount Minimum required stake amount
/// @return result Result indicating success or specific error
pub fn validate_yield_parameters(
    amount: u256,
    protocol: ContractAddress,
    min_stake_amount: u256
) -> Result<(), BitFlowError> {
    if amount == 0 {
        return Result::Err(BitFlowError::ZeroAmount);
    }
    
    if protocol.is_zero() {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    if amount < min_stake_amount {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    Result::Ok(())
}

/// Validates bridge transaction parameters
/// @param amount The amount to bridge
/// @param min_bridge_amount Minimum required bridge amount
/// @param max_bridge_amount Maximum allowed bridge amount
/// @return result Result indicating success or specific error
pub fn validate_bridge_parameters(
    amount: u256,
    min_bridge_amount: u256,
    max_bridge_amount: u256
) -> Result<(), BitFlowError> {
    if amount == 0 {
        return Result::Err(BitFlowError::ZeroAmount);
    }
    
    if amount < min_bridge_amount {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    if amount > max_bridge_amount {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    Result::Ok(())
}

/// Validates subscription lifecycle state transitions
/// @param subscription The subscription to validate
/// @param new_status The new status to transition to
/// @param current_time Current timestamp
/// @return result Result indicating success or specific error
pub fn validate_subscription_lifecycle(
    subscription: Subscription,
    new_status: SubscriptionStatus,
    current_time: u64
) -> Result<(), BitFlowError> {
    // Check if subscription exists
    if subscription.id == 0 {
        return Result::Err(BitFlowError::StreamNotFound);
    }
    
    // Validate state transitions
    match subscription.status {
        SubscriptionStatus::Active => {
            // Active can transition to Paused, Cancelled, or Expired
            match new_status {
                SubscriptionStatus::Paused => Result::Ok(()),
                SubscriptionStatus::Cancelled => Result::Ok(()),
                SubscriptionStatus::Expired => {
                    if current_time >= subscription.end_time {
                        Result::Ok(())
                    } else {
                        Result::Err(BitFlowError::InvalidParameters)
                    }
                },
                _ => Result::Err(BitFlowError::InvalidParameters)
            }
        },
        SubscriptionStatus::Paused => {
            // Paused can transition to Active or Cancelled
            match new_status {
                SubscriptionStatus::Active => Result::Ok(()),
                SubscriptionStatus::Cancelled => Result::Ok(()),
                _ => Result::Err(BitFlowError::InvalidParameters)
            }
        },
        SubscriptionStatus::Cancelled => {
            // Cancelled is final state
            Result::Err(BitFlowError::InvalidParameters)
        },
        SubscriptionStatus::Expired => {
            // Expired can only transition to Active if auto-renew is enabled
            match new_status {
                SubscriptionStatus::Active => {
                    if subscription.auto_renew {
                        Result::Ok(())
                    } else {
                        Result::Err(BitFlowError::InvalidParameters)
                    }
                },
                _ => Result::Err(BitFlowError::InvalidParameters)
            }
        }
    }
}

/// Validates subscription creation parameters
/// @param subscriber The subscriber address
/// @param provider The provider address
/// @param duration The subscription duration
/// @param current_time Current timestamp
/// @return result Result indicating success or specific error
pub fn validate_subscription_creation(
    subscriber: ContractAddress,
    provider: ContractAddress,
    duration: u64,
    current_time: u64
) -> Result<(), BitFlowError> {
    if subscriber.is_zero() {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    if provider.is_zero() {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    if subscriber == provider {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    if duration == 0 {
        return Result::Err(BitFlowError::InvalidTimeRange);
    }
    
    // Ensure duration is reasonable (not more than 10 years)
    let max_duration = 315360000_u64; // 10 years in seconds
    if duration > max_duration {
        return Result::Err(BitFlowError::InvalidTimeRange);
    }
    
    Result::Ok(())
}

/// Validates yield position parameters
/// @param yield_position The yield position to validate
/// @param current_time Current timestamp
/// @return result Result indicating success or specific error
pub fn validate_yield_position(
    yield_position: YieldPosition,
    current_time: u64
) -> Result<(), BitFlowError> {
    if yield_position.stream_id == 0 {
        return Result::Err(BitFlowError::StreamNotFound);
    }
    
    if yield_position.protocol.is_zero() {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    if yield_position.staked_amount == 0 {
        return Result::Err(BitFlowError::ZeroAmount);
    }
    
    // Validate that last_update is not in the future
    if yield_position.last_update > current_time {
        return Result::Err(BitFlowError::InvalidTimeRange);
    }
    
    Result::Ok(())
}

/// Validates yield position update parameters
/// @param old_position The current yield position
/// @param new_staked_amount The new staked amount
/// @param new_earned_yield The new earned yield amount
/// @param current_time Current timestamp
/// @return result Result indicating success or specific error
pub fn validate_yield_position_update(
    old_position: YieldPosition,
    new_staked_amount: u256,
    new_earned_yield: u256,
    current_time: u64
) -> Result<(), BitFlowError> {
    // Validate the old position first
    validate_yield_position(old_position, current_time)?;
    
    // Ensure time has progressed
    if current_time < old_position.last_update {
        return Result::Err(BitFlowError::InvalidTimeRange);
    }
    
    // Earned yield should not decrease (unless there's a withdrawal)
    if new_earned_yield < old_position.earned_yield {
        return Result::Err(BitFlowError::InvalidParameters);
    }
    
    Result::Ok(())
}