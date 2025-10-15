use starknet::ContractAddress;
use crate::types::{PaymentStream, BitFlowError};

#[starknet::interface]
pub trait IStreamManager<TContractState> {
    /// Creates a new payment stream
    /// @param recipient The address that will receive the streamed payments
    /// @param amount Total amount to be streamed
    /// @param rate Rate of payment per second
    /// @param duration Duration of the stream in seconds
    /// @return stream_id The unique identifier for the created stream
    fn create_stream(
        ref self: TContractState,
        recipient: ContractAddress,
        amount: u256,
        rate: u256,
        duration: u64
    ) -> u256;
    
    /// Cancels an active payment stream
    /// @param stream_id The unique identifier of the stream to cancel
    /// @return success True if cancellation was successful
    fn cancel_stream(ref self: TContractState, stream_id: u256) -> bool;
    
    /// Pauses an active payment stream
    /// @param stream_id The unique identifier of the stream to pause
    /// @return success True if pause was successful
    fn pause_stream(ref self: TContractState, stream_id: u256) -> bool;
    
    /// Resumes a paused payment stream
    /// @param stream_id The unique identifier of the stream to resume
    /// @return success True if resume was successful
    fn resume_stream(ref self: TContractState, stream_id: u256) -> bool;
    
    /// Allows recipient to withdraw available funds from a stream
    /// @param stream_id The unique identifier of the stream
    /// @return amount The amount withdrawn
    fn withdraw_from_stream(ref self: TContractState, stream_id: u256) -> u256;
    
    /// Gets the current withdrawable balance for a stream
    /// @param stream_id The unique identifier of the stream
    /// @return balance The current withdrawable balance
    fn get_stream_balance(self: @TContractState, stream_id: u256) -> u256;
    
    /// Gets complete stream information
    /// @param stream_id The unique identifier of the stream
    /// @return stream The PaymentStream struct with all details
    fn get_stream(self: @TContractState, stream_id: u256) -> PaymentStream;
    
    /// Gets all stream IDs for a specific user (sender or recipient)
    /// @param user The address to query streams for
    /// @return stream_ids Array of stream IDs associated with the user
    fn get_user_streams(self: @TContractState, user: ContractAddress) -> Array<u256>;
    
    /// Checks if a stream is active and valid
    /// @param stream_id The unique identifier of the stream
    /// @return is_active True if stream is active
    fn is_stream_active(self: @TContractState, stream_id: u256) -> bool;
    
    /// Gets the total number of streams created
    /// @return count Total number of streams
    fn get_stream_count(self: @TContractState) -> u256;
    
    /// Checks if a stream is currently paused
    /// @param stream_id The unique identifier of the stream
    /// @return is_paused True if stream is paused
    fn is_stream_paused(self: @TContractState, stream_id: u256) -> bool;
    
    /// Processes automatic payment distribution for a stream
    /// @param stream_id The unique identifier of the stream
    /// @return amount The amount automatically distributed
    fn process_automatic_payment(ref self: TContractState, stream_id: u256) -> u256;
    
    /// Processes automatic payments for multiple streams in batch
    /// @param stream_ids Array of stream IDs to process
    /// @return total_processed Total amount processed across all streams
    fn batch_process_payments(ref self: TContractState, stream_ids: Array<u256>) -> u256;
    
    /// Gets the accumulated payments for a stream (total distributed automatically)
    /// @param stream_id The unique identifier of the stream
    /// @return accumulated The total amount distributed automatically
    fn get_accumulated_payments(self: @TContractState, stream_id: u256) -> u256;
    
    /// Gets the last payment timestamp for a stream
    /// @param stream_id The unique identifier of the stream
    /// @return timestamp The last time automatic payment was processed
    fn get_last_payment_time(self: @TContractState, stream_id: u256) -> u64;
}