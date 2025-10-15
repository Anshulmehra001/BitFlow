use starknet::ContractAddress;
use crate::types::{YieldPosition, BitFlowError};

#[starknet::interface]
pub trait IYieldManager<TContractState> {
    /// Stakes idle funds from a stream to generate yield
    /// @param stream_id The unique identifier of the stream
    /// @param amount The amount to stake
    /// @param protocol The DeFi protocol to stake with
    /// @return success True if staking was successful
    fn stake_idle_funds(
        ref self: TContractState,
        stream_id: u256,
        amount: u256,
        protocol: ContractAddress
    ) -> bool;
    
    /// Unstakes funds from a yield protocol
    /// @param stream_id The unique identifier of the stream
    /// @param amount The amount to unstake
    /// @return success True if unstaking was successful
    fn unstake_funds(ref self: TContractState, stream_id: u256, amount: u256) -> bool;
    
    /// Distributes earned yield back to the stream balance
    /// @param stream_id The unique identifier of the stream
    /// @return yield_amount The amount of yield distributed
    fn distribute_yield(ref self: TContractState, stream_id: u256) -> u256;
    
    /// Claims all available yield for a stream
    /// @param stream_id The unique identifier of the stream
    /// @return claimed_amount The total amount of yield claimed
    fn claim_yield(ref self: TContractState, stream_id: u256) -> u256;
    
    /// Gets the current yield rate for a specific protocol
    /// @param protocol The DeFi protocol address
    /// @return rate The current annual yield rate (in basis points)
    fn get_yield_rate(self: @TContractState, protocol: ContractAddress) -> u256;
    
    /// Gets the yield position for a specific stream
    /// @param stream_id The unique identifier of the stream
    /// @return position The YieldPosition struct with details
    fn get_yield_position(self: @TContractState, stream_id: u256) -> YieldPosition;
    
    /// Gets total earned yield for a stream
    /// @param stream_id The unique identifier of the stream
    /// @return total_yield The total yield earned to date
    fn get_total_earned_yield(self: @TContractState, stream_id: u256) -> u256;
    
    /// Enables yield generation for a stream
    /// @param stream_id The unique identifier of the stream
    /// @param protocol The preferred DeFi protocol for yield generation
    /// @return success True if yield was enabled
    fn enable_yield(
        ref self: TContractState,
        stream_id: u256,
        protocol: ContractAddress
    ) -> bool;
    
    /// Disables yield generation for a stream
    /// @param stream_id The unique identifier of the stream
    /// @return success True if yield was disabled
    fn disable_yield(ref self: TContractState, stream_id: u256) -> bool;
    
    /// Gets all supported yield protocols
    /// @return protocols Array of supported DeFi protocol addresses
    fn get_supported_protocols(self: @TContractState) -> Array<ContractAddress>;
    
    /// Adds a new supported yield protocol
    /// @param protocol The DeFi protocol address to add
    /// @param min_stake_amount Minimum amount required for staking
    /// @return success True if protocol was added
    fn add_yield_protocol(
        ref self: TContractState,
        protocol: ContractAddress,
        min_stake_amount: u256
    ) -> bool;
    
    /// Automatically selects the best yield strategy based on current rates
    /// @param amount The amount to be staked
    /// @return protocol The selected protocol address
    fn select_optimal_yield_strategy(self: @TContractState, amount: u256) -> ContractAddress;
}