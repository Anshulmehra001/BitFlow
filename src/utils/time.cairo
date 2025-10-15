use starknet::get_block_timestamp;

/// Gets the current block timestamp
/// @return timestamp Current block timestamp in seconds
pub fn get_current_time() -> u64 {
    get_block_timestamp()
}

/// Checks if a given timestamp is in the past
/// @param timestamp The timestamp to check
/// @return is_past True if timestamp is in the past
pub fn is_past(timestamp: u64) -> bool {
    get_current_time() > timestamp
}

/// Checks if a given timestamp is in the future
/// @param timestamp The timestamp to check
/// @return is_future True if timestamp is in the future
pub fn is_future(timestamp: u64) -> bool {
    get_current_time() < timestamp
}

/// Calculates the time elapsed since a given timestamp
/// @param start_time The starting timestamp
/// @return elapsed Time elapsed in seconds, or 0 if start_time is in the future
pub fn time_elapsed_since(start_time: u64) -> u64 {
    let current_time = get_current_time();
    if current_time > start_time {
        current_time - start_time
    } else {
        0
    }
}

/// Calculates the time remaining until a given timestamp
/// @param end_time The ending timestamp
/// @return remaining Time remaining in seconds, or 0 if end_time is in the past
pub fn time_remaining_until(end_time: u64) -> u64 {
    let current_time = get_current_time();
    if end_time > current_time {
        end_time - current_time
    } else {
        0
    }
}

/// Checks if a time period has elapsed since a given timestamp
/// @param start_time The starting timestamp
/// @param period The period duration in seconds
/// @return has_elapsed True if the period has elapsed
pub fn has_period_elapsed(start_time: u64, period: u64) -> bool {
    time_elapsed_since(start_time) >= period
}

/// Adds a duration to a timestamp safely
/// @param timestamp The base timestamp
/// @param duration The duration to add in seconds
/// @return new_timestamp The resulting timestamp
pub fn add_duration(timestamp: u64, duration: u64) -> u64 {
    timestamp + duration
}

/// Subtracts a duration from a timestamp safely
/// @param timestamp The base timestamp
/// @param duration The duration to subtract in seconds
/// @return new_timestamp The resulting timestamp, or 0 if underflow
pub fn subtract_duration(timestamp: u64, duration: u64) -> u64 {
    if timestamp >= duration {
        timestamp - duration
    } else {
        0
    }
}

/// Converts days to seconds
/// @param days Number of days
/// @return seconds Equivalent seconds
pub fn days_to_seconds(days: u64) -> u64 {
    days * 24 * 60 * 60
}

/// Converts hours to seconds
/// @param hours Number of hours
/// @return seconds Equivalent seconds
pub fn hours_to_seconds(hours: u64) -> u64 {
    hours * 60 * 60
}

/// Converts minutes to seconds
/// @param minutes Number of minutes
/// @return seconds Equivalent seconds
pub fn minutes_to_seconds(minutes: u64) -> u64 {
    minutes * 60
}