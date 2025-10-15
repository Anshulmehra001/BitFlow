use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub enum PricingModel {
    Fixed: u256,                    // Fixed price per access
    Tiered: TieredPricing,         // Different prices based on usage tiers
    TimeBasedDecay: TimeDecayPricing, // Price decreases over time
    DynamicDemand: DynamicPricing,  // Price adjusts based on demand
}

#[derive(Drop, Serde, starknet::Store)]
pub struct TieredPricing {
    pub tier1_threshold: u256,      // Access count threshold for tier 1
    pub tier1_price: u256,          // Price for tier 1
    pub tier2_threshold: u256,      // Access count threshold for tier 2
    pub tier2_price: u256,          // Price for tier 2
    pub tier3_price: u256,          // Price for tier 3 (unlimited)
}

#[derive(Drop, Serde, starknet::Store)]
pub struct TimeDecayPricing {
    pub initial_price: u256,        // Starting price
    pub decay_rate: u256,           // Rate of price decay (per day)
    pub minimum_price: u256,        // Floor price
    pub creation_time: u64,         // When content was created
}

#[derive(Drop, Serde, starknet::Store)]
pub struct DynamicPricing {
    pub base_price: u256,           // Base price
    pub demand_multiplier: u256,    // Multiplier based on recent demand
    pub max_price: u256,            // Maximum allowed price
    pub adjustment_period: u64,     // How often to adjust price (seconds)
    pub last_adjustment: u64,       // Last time price was adjusted
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ContentPricing {
    pub content_id: u256,
    pub creator: ContractAddress,
    pub pricing_model: PricingModel,
    pub is_active: bool,
    pub created_at: u64,
    pub updated_at: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct AccessAttempt {
    pub user: ContractAddress,
    pub content_id: u256,
    pub timestamp: u64,
    pub price_paid: u256,
    pub success: bool,
    pub failure_reason: felt252,
}

#[starknet::interface]
pub trait IContentPricingManager<TContractState> {
    /// Sets pricing model for content
    /// @param content_id The unique identifier of the content
    /// @param pricing_model The pricing model to apply
    /// @return success True if pricing was set successfully
    fn set_content_pricing(
        ref self: TContractState,
        content_id: u256,
        pricing_model: PricingModel
    ) -> bool;
    
    /// Gets current price for content access
    /// @param content_id The unique identifier of the content
    /// @param user The user requesting access (for personalized pricing)
    /// @return price Current price for access
    fn get_current_price(
        self: @TContractState,
        content_id: u256,
        user: ContractAddress
    ) -> u256;
    
    /// Updates dynamic pricing based on recent demand
    /// @param content_id The unique identifier of the content
    /// @return new_price The updated price
    fn update_dynamic_pricing(
        ref self: TContractState,
        content_id: u256
    ) -> u256;
    
    /// Records an access attempt (successful or failed)
    /// @param content_id The unique identifier of the content
    /// @param user The user attempting access
    /// @param price_paid The price paid (0 if failed)
    /// @param success Whether the access was successful
    /// @param failure_reason Reason for failure (if applicable)
    /// @return attempt_id Unique identifier for the attempt
    fn record_access_attempt(
        ref self: TContractState,
        content_id: u256,
        user: ContractAddress,
        price_paid: u256,
        success: bool,
        failure_reason: felt252
    ) -> u256;
    
    /// Gets pricing information for content
    /// @param content_id The unique identifier of the content
    /// @return pricing The ContentPricing struct with all details
    fn get_content_pricing(
        self: @TContractState,
        content_id: u256
    ) -> ContentPricing;
    
    /// Validates if user can afford current price
    /// @param content_id The unique identifier of the content
    /// @param user The user to check
    /// @param available_balance User's available balance
    /// @return can_afford True if user can afford the content
    fn can_afford_content(
        self: @TContractState,
        content_id: u256,
        user: ContractAddress,
        available_balance: u256
    ) -> bool;
    
    /// Gets access statistics for content
    /// @param content_id The unique identifier of the content
    /// @param time_period Period to analyze (in seconds from now)
    /// @return stats Access statistics including success/failure rates
    fn get_access_statistics(
        self: @TContractState,
        content_id: u256,
        time_period: u64
    ) -> (u256, u256, u256); // (total_attempts, successful_accesses, total_revenue)
    
    /// Enforces payment failure handling
    /// @param content_id The unique identifier of the content
    /// @param user The user who failed to pay
    /// @param required_amount The amount that was required
    /// @param available_amount The amount user had available
    /// @return action_taken The action taken (block, warn, etc.)
    fn handle_payment_failure(
        ref self: TContractState,
        content_id: u256,
        user: ContractAddress,
        required_amount: u256,
        available_amount: u256
    ) -> felt252;
    
    /// Gets user's access history for content
    /// @param user The user to query
    /// @param content_id The content to query (0 for all content)
    /// @param limit Maximum number of attempts to return
    /// @return attempts Array of access attempts
    fn get_user_access_history(
        self: @TContractState,
        user: ContractAddress,
        content_id: u256,
        limit: u32
    ) -> Array<AccessAttempt>;
    
    /// Bulk updates pricing for multiple content items
    /// @param content_ids Array of content IDs to update
    /// @param pricing_models Array of pricing models (must match content_ids length)
    /// @return success_count Number of successful updates
    fn bulk_update_pricing(
        ref self: TContractState,
        content_ids: Array<u256>,
        pricing_models: Array<PricingModel>
    ) -> u32;
}