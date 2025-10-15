use starknet::ContractAddress;
use crate::types::BitFlowError;

#[starknet::interface]
pub trait IEscrowManager<TContractState> {
    /// Deposits funds into escrow for a specific stream
    /// @param stream_id The unique identifier of the stream
    /// @param amount The amount to deposit
    /// @return success True if deposit was successful
    fn deposit_funds(ref self: TContractState, stream_id: u256, amount: u256) -> bool;
    
    /// Releases funds from escrow to a recipient
    /// @param stream_id The unique identifier of the stream
    /// @param amount The amount to release
    /// @param recipient The address to receive the funds
    /// @return success True if release was successful
    fn release_funds(
        ref self: TContractState, 
        stream_id: u256, 
        amount: u256, 
        recipient: ContractAddress
    ) -> bool;
    
    /// Returns funds to the original sender (for cancelled streams)
    /// @param stream_id The unique identifier of the stream
    /// @param amount The amount to return
    /// @param sender The original sender address
    /// @return success True if return was successful
    fn return_funds(
        ref self: TContractState,
        stream_id: u256,
        amount: u256,
        sender: ContractAddress
    ) -> bool;
    
    /// Emergency pause mechanism to halt all operations
    /// @return success True if emergency pause was activated
    fn emergency_pause(ref self: TContractState) -> bool;
    
    /// Resume operations after emergency pause
    /// @return success True if operations were resumed
    fn resume_operations(ref self: TContractState) -> bool;
    
    /// Gets the current escrow balance for a specific stream
    /// @param stream_id The unique identifier of the stream
    /// @return balance The current escrow balance
    fn get_escrow_balance(self: @TContractState, stream_id: u256) -> u256;
    
    /// Gets the total amount held in escrow across all streams
    /// @return total_balance The total escrow balance
    fn get_total_escrow_balance(self: @TContractState) -> u256;
    
    /// Checks if the escrow system is currently paused
    /// @return is_paused True if system is paused
    fn is_paused(self: @TContractState) -> bool;
    
    /// Validates that sufficient funds are available for a stream
    /// @param stream_id The unique identifier of the stream
    /// @param required_amount The amount needed
    /// @return is_sufficient True if sufficient funds are available
    fn validate_sufficient_funds(
        self: @TContractState, 
        stream_id: u256, 
        required_amount: u256
    ) -> bool;
    
    /// Emergency withdrawal function for fund recovery
    /// @param stream_id The unique identifier of the stream
    /// @param recipient The address to receive the emergency withdrawal
    /// @return amount The amount withdrawn in emergency
    fn emergency_withdraw(
        ref self: TContractState,
        stream_id: u256,
        recipient: ContractAddress
    ) -> u256;
}