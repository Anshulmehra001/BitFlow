// Mathematical utility functions for BitFlow protocol

/// Calculates the amount that should be available for withdrawal at a given time
/// @param total_amount Total amount in the stream
/// @param rate_per_second Payment rate per second
/// @param start_time Stream start timestamp
/// @param current_time Current timestamp
/// @param withdrawn_amount Amount already withdrawn
/// @return available_amount Amount available for withdrawal
pub fn calculate_available_amount(
    total_amount: u256,
    rate_per_second: u256,
    start_time: u64,
    current_time: u64,
    withdrawn_amount: u256
) -> u256 {
    if current_time <= start_time {
        return 0;
    }
    
    let elapsed_time = current_time - start_time;
    let streamed_amount = rate_per_second * elapsed_time.into();
    
    // Cap at total amount
    let max_streamed = if streamed_amount > total_amount {
        total_amount
    } else {
        streamed_amount
    };
    
    // Subtract already withdrawn amount
    if max_streamed > withdrawn_amount {
        max_streamed - withdrawn_amount
    } else {
        0
    }
}

/// Calculates the end time for a stream given start time and duration
/// @param start_time Stream start timestamp
/// @param duration Stream duration in seconds
/// @return end_time Stream end timestamp
pub fn calculate_end_time(start_time: u64, duration: u64) -> u64 {
    start_time + duration
}

/// Calculates the rate per second given total amount and duration
/// @param total_amount Total amount to be streamed
/// @param duration Stream duration in seconds
/// @return rate_per_second Payment rate per second
pub fn calculate_rate_per_second(total_amount: u256, duration: u64) -> u256 {
    if duration == 0 {
        return 0;
    }
    total_amount / duration.into()
}

/// Calculates yield earned over a period
/// @param principal Principal amount staked
/// @param annual_rate Annual yield rate in basis points (e.g., 500 = 5%)
/// @param time_period Time period in seconds
/// @return yield_earned Yield earned over the period
pub fn calculate_yield(principal: u256, annual_rate: u256, time_period: u64) -> u256 {
    let seconds_per_year: u256 = 31536000; // 365 * 24 * 60 * 60
    let basis_points: u256 = 10000;
    
    (principal * annual_rate * time_period.into()) / (basis_points * seconds_per_year)
}

/// Safely adds two u256 values with overflow protection
/// @param a First value
/// @param b Second value
/// @return result Sum of a and b, or maximum u256 if overflow
pub fn safe_add(a: u256, b: u256) -> u256 {
    let result = a + b;
    if result < a {
        // Overflow occurred, return max value
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    } else {
        result
    }
}

/// Safely subtracts two u256 values with underflow protection
/// @param a First value (minuend)
/// @param b Second value (subtrahend)
/// @return result Difference of a and b, or 0 if underflow
pub fn safe_sub(a: u256, b: u256) -> u256 {
    if a >= b {
        a - b
    } else {
        0
    }
}