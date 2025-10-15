use starknet::ContractAddress;
use crate::types::BitFlowError;

#[derive(Drop, Serde, starknet::Store)]
pub struct MicroPayment {
    pub id: u256,
    pub payer: ContractAddress,
    pub content_creator: ContractAddress,
    pub content_id: u256,
    pub amount: u256,
    pub timestamp: u64,
    pub stream_id: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ContentAccess {
    pub content_id: u256,
    pub creator: ContractAddress,
    pub price_per_access: u256,
    pub is_active: bool,
    pub total_accesses: u256,
    pub total_revenue: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct UserBalance {
    pub user: ContractAddress,
    pub available_balance: u256,
    pub reserved_balance: u256,
    pub low_balance_threshold: u256,
    pub last_notification: u64,
}

#[starknet::interface]
pub trait IMicroPaymentManager<TContractState> {
    /// Processes a micro-payment for content access
    /// @param content_id The unique identifier of the content
    /// @param stream_id The stream to deduct payment from
    /// @return payment_id The unique identifier for the payment
    fn process_micro_payment(
        ref self: TContractState,
        content_id: u256,
        stream_id: u256
    ) -> u256;
    
    /// Registers new content with pricing
    /// @param content_id The unique identifier for the content
    /// @param price_per_access The price for each access in wei (supports sub-cent)
    /// @return success True if registration was successful
    fn register_content(
        ref self: TContractState,
        content_id: u256,
        price_per_access: u256
    ) -> bool;
    
    /// Updates content pricing
    /// @param content_id The unique identifier of the content
    /// @param new_price The new price per access
    /// @return success True if update was successful
    fn update_content_price(
        ref self: TContractState,
        content_id: u256,
        new_price: u256
    ) -> bool;
    
    /// Deactivates content (prevents new accesses)
    /// @param content_id The unique identifier of the content
    /// @return success True if deactivation was successful
    fn deactivate_content(
        ref self: TContractState,
        content_id: u256
    ) -> bool;
    
    /// Checks if user has sufficient balance for content access
    /// @param user The user address to check
    /// @param content_id The content they want to access
    /// @return can_access True if user can afford the content
    fn can_access_content(
        self: @TContractState,
        user: ContractAddress,
        content_id: u256
    ) -> bool;
    
    /// Gets content information and pricing
    /// @param content_id The unique identifier of the content
    /// @return content The ContentAccess struct with all details
    fn get_content_info(
        self: @TContractState,
        content_id: u256
    ) -> ContentAccess;
    
    /// Gets user's current balance information
    /// @param user The user address to query
    /// @return balance The UserBalance struct with balance details
    fn get_user_balance(
        self: @TContractState,
        user: ContractAddress
    ) -> UserBalance;
    
    /// Sets low balance threshold for notifications
    /// @param threshold The balance threshold below which to notify
    /// @return success True if threshold was set
    fn set_low_balance_threshold(
        ref self: TContractState,
        threshold: u256
    ) -> bool;
    
    /// Checks if user balance is below threshold
    /// @param user The user address to check
    /// @return is_low True if balance is below threshold
    fn is_balance_low(
        self: @TContractState,
        user: ContractAddress
    ) -> bool;
    
    /// Gets payment history for a user
    /// @param user The user address to query
    /// @param limit Maximum number of payments to return
    /// @return payments Array of recent MicroPayment structs
    fn get_payment_history(
        self: @TContractState,
        user: ContractAddress,
        limit: u32
    ) -> Array<MicroPayment>;
    
    /// Gets content access statistics for creators
    /// @param creator The creator address to query
    /// @return content_ids Array of content IDs owned by creator
    fn get_creator_content(
        self: @TContractState,
        creator: ContractAddress
    ) -> Array<u256>;
    
    /// Calculates available balance from active streams
    /// @param user The user address to calculate for
    /// @return available_balance Total available balance from all streams
    fn calculate_available_balance(
        self: @TContractState,
        user: ContractAddress
    ) -> u256;
    
    /// Reserves balance for upcoming payments
    /// @param user The user address
    /// @param amount The amount to reserve
    /// @return success True if reservation was successful
    fn reserve_balance(
        ref self: TContractState,
        user: ContractAddress,
        amount: u256
    ) -> bool;
    
    /// Releases reserved balance
    /// @param user The user address
    /// @param amount The amount to release
    /// @return success True if release was successful
    fn release_reserved_balance(
        ref self: TContractState,
        user: ContractAddress,
        amount: u256
    ) -> bool;
}