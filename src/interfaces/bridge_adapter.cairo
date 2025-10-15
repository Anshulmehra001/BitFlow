use starknet::ContractAddress;
use crate::types::{BridgeStatus, BitFlowError};

#[starknet::interface]
pub trait IAtomiqBridgeAdapter<TContractState> {
    /// Locks Bitcoin and mints wrapped Bitcoin on Starknet
    /// @param amount The amount of Bitcoin to lock (in satoshis)
    /// @param recipient The Starknet address to receive wrapped Bitcoin
    /// @param bitcoin_tx_hash The Bitcoin transaction hash for verification
    /// @return bridge_tx_id The unique identifier for this bridge transaction
    fn lock_bitcoin(
        ref self: TContractState,
        amount: u256,
        recipient: ContractAddress,
        bitcoin_tx_hash: felt252
    ) -> u256;
    
    /// Unlocks Bitcoin by burning wrapped Bitcoin on Starknet
    /// @param stream_id The stream ID requesting the unlock
    /// @param amount The amount of wrapped Bitcoin to burn
    /// @param bitcoin_address The Bitcoin address to receive unlocked Bitcoin
    /// @return success True if unlock was initiated successfully
    fn unlock_bitcoin(
        ref self: TContractState,
        stream_id: u256,
        amount: u256,
        bitcoin_address: felt252
    ) -> bool;
    
    /// Gets the status of a bridge transaction
    /// @param bridge_tx_id The unique identifier of the bridge transaction
    /// @return status The current status of the bridge transaction
    fn get_bridge_status(self: @TContractState, bridge_tx_id: u256) -> BridgeStatus;
    
    /// Verifies a Bitcoin transaction for bridge operations
    /// @param bitcoin_tx_hash The Bitcoin transaction hash to verify
    /// @param expected_amount The expected amount in the transaction
    /// @param expected_recipient The expected recipient address
    /// @return is_valid True if transaction is valid
    fn verify_bitcoin_transaction(
        self: @TContractState,
        bitcoin_tx_hash: felt252,
        expected_amount: u256,
        expected_recipient: ContractAddress
    ) -> bool;
    
    /// Gets the current exchange rate between Bitcoin and wrapped Bitcoin
    /// @return rate The exchange rate (1:1 typically, but may include fees)
    fn get_exchange_rate(self: @TContractState) -> u256;
    
    /// Gets the minimum amount required for bridge operations
    /// @return min_amount The minimum amount in satoshis
    fn get_minimum_bridge_amount(self: @TContractState) -> u256;
    
    /// Gets the bridge fee for a specific amount
    /// @param amount The amount to bridge
    /// @return fee The bridge fee in satoshis
    fn get_bridge_fee(self: @TContractState, amount: u256) -> u256;
    
    /// Estimates the time required for bridge confirmation
    /// @param amount The amount being bridged
    /// @return estimated_time The estimated confirmation time in seconds
    fn estimate_bridge_time(self: @TContractState, amount: u256) -> u64;
    
    /// Gets the total amount of Bitcoin locked in the bridge
    /// @return total_locked The total locked Bitcoin amount
    fn get_total_locked_bitcoin(self: @TContractState) -> u256;
    
    /// Gets the wrapped Bitcoin balance for a specific address
    /// @param address The Starknet address to check
    /// @return balance The wrapped Bitcoin balance
    fn get_wrapped_bitcoin_balance(self: @TContractState, address: ContractAddress) -> u256;
    
    /// Emergency function to pause bridge operations
    /// @return success True if bridge was paused
    fn pause_bridge(ref self: TContractState) -> bool;
    
    /// Resume bridge operations after pause
    /// @return success True if bridge was resumed
    fn resume_bridge(ref self: TContractState) -> bool;
    
    /// Process Bitcoin to wBTC conversion with confirmation waiting
    /// @param bridge_tx_id The bridge transaction ID
    /// @param bitcoin_confirmations Number of Bitcoin confirmations received
    /// @return success True if conversion was processed successfully
    fn process_bitcoin_to_wbtc_conversion(
        ref self: TContractState,
        bridge_tx_id: u256,
        bitcoin_confirmations: u8
    ) -> bool;
    
    /// Process wBTC to Bitcoin conversion
    /// @param bridge_tx_id The bridge transaction ID
    /// @param bitcoin_tx_hash The Bitcoin transaction hash for the unlock
    /// @return success True if conversion was processed successfully
    fn process_wbtc_to_bitcoin_conversion(
        ref self: TContractState,
        bridge_tx_id: u256,
        bitcoin_tx_hash: felt252
    ) -> bool;
    
    /// Handle bridge transaction failure
    /// @param bridge_tx_id The bridge transaction ID
    /// @param failure_reason The reason for failure
    /// @return success True if failure was handled successfully
    fn handle_bridge_failure(
        ref self: TContractState,
        bridge_tx_id: u256,
        failure_reason: felt252
    ) -> bool;
    
    /// Retry a failed bridge transaction
    /// @param bridge_tx_id The bridge transaction ID
    /// @return success True if retry was initiated successfully
    fn retry_bridge_transaction(ref self: TContractState, bridge_tx_id: u256) -> bool;
    
    /// Cancel a timed out transaction
    /// @param bridge_tx_id The bridge transaction ID
    /// @return success True if cancellation was successful
    fn cancel_timed_out_transaction(ref self: TContractState, bridge_tx_id: u256) -> bool;
}