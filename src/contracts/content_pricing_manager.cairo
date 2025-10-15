use starknet::{ContractAddress, get_caller_address};
use crate::interfaces::content_pricing::{
    IContentPricingManager, PricingModel, TieredPricing, TimeDecayPricing, 
    DynamicPricing, ContentPricing, AccessAttempt
};
use crate::utils::time::get_current_time;
use crate::utils::math::calculate_percentage;

#[starknet::contract]
pub mod ContentPricingManager {
    use super::*;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    #[storage]
    struct Storage {
        // Content pricing storage
        content_pricing: Map<u256, ContentPricing>,
        
        // Access attempt tracking
        access_attempts: Map<u256, AccessAttempt>,
        attempt_count: u256,
        
        // User access history
        user_attempts: Map<(ContractAddress, u256), u256>, // (user, index) -> attempt_id
        user_attempt_count: Map<ContractAddress, u256>,
        
        // Content access history
        content_attempts: Map<(u256, u256), u256>, // (content_id, index) -> attempt_id
        content_attempt_count: Map<u256, u256>,
        
        // Dynamic pricing tracking
        recent_access_count: Map<(u256, u64), u256>, // (content_id, time_bucket) -> access_count
        
        // Contract settings
        owner: ContractAddress,
        max_dynamic_multiplier: u256,
        time_bucket_size: u64, // Size of time buckets for demand tracking (seconds)
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PricingModelSet: PricingModelSet,
        PriceUpdated: PriceUpdated,
        AccessAttemptRecorded: AccessAttemptRecorded,
        PaymentFailureHandled: PaymentFailureHandled,
        DynamicPriceAdjusted: DynamicPriceAdjusted,
        BulkPricingUpdated: BulkPricingUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PricingModelSet {
        #[key]
        pub content_id: u256,
        #[key]
        pub creator: ContractAddress,
        pub pricing_model_type: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PriceUpdated {
        #[key]
        pub content_id: u256,
        pub old_price: u256,
        pub new_price: u256,
        pub reason: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AccessAttemptRecorded {
        #[key]
        pub attempt_id: u256,
        #[key]
        pub user: ContractAddress,
        #[key]
        pub content_id: u256,
        pub price_paid: u256,
        pub success: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PaymentFailureHandled {
        #[key]
        pub user: ContractAddress,
        #[key]
        pub content_id: u256,
        pub required_amount: u256,
        pub available_amount: u256,
        pub action_taken: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DynamicPriceAdjusted {
        #[key]
        pub content_id: u256,
        pub old_price: u256,
        pub new_price: u256,
        pub demand_factor: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BulkPricingUpdated {
        pub updated_count: u32,
        pub failed_count: u32,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        max_dynamic_multiplier: u256,
        time_bucket_size: u64
    ) {
        self.owner.write(owner);
        self.attempt_count.write(0);
        self.max_dynamic_multiplier.write(max_dynamic_multiplier);
        self.time_bucket_size.write(time_bucket_size);
    }

    #[abi(embed_v0)]
    impl ContentPricingManagerImpl of IContentPricingManager<ContractState> {
        /// Sets pricing model for content
        fn set_content_pricing(
            ref self: ContractState,
            content_id: u256,
            pricing_model: PricingModel
        ) -> bool {
            let caller = get_caller_address();
            let current_time = get_current_time();
            
            // Validate content ID
            assert(content_id > 0, 'Invalid content ID');
            
            // Check if content already has pricing (only creator can update)
            let existing_pricing = self.content_pricing.read(content_id);
            if existing_pricing.creator.is_non_zero() {
                assert(existing_pricing.creator == caller, 'Unauthorized access');
            }
            
            // Create or update content pricing
            let content_pricing = ContentPricing {
                content_id,
                creator: caller,
                pricing_model,
                is_active: true,
                created_at: if existing_pricing.created_at == 0 { current_time } else { existing_pricing.created_at },
                updated_at: current_time,
            };
            
            self.content_pricing.write(content_id, content_pricing);
            
            // Emit event with pricing model type
            let model_type = match pricing_model {
                PricingModel::Fixed(_) => 'fixed',
                PricingModel::Tiered(_) => 'tiered',
                PricingModel::TimeBasedDecay(_) => 'time_decay',
                PricingModel::DynamicDemand(_) => 'dynamic',
            };
            
            self.emit(PricingModelSet {
                content_id,
                creator: caller,
                pricing_model_type: model_type,
            });
            
            true
        }
        
        /// Gets current price for content access
        fn get_current_price(
            self: @ContractState,
            content_id: u256,
            user: ContractAddress
        ) -> u256 {
            let pricing = self.content_pricing.read(content_id);
            assert(pricing.creator.is_non_zero(), 'Content pricing not found');
            assert(pricing.is_active, 'Content pricing inactive');
            
            match pricing.pricing_model {
                PricingModel::Fixed(price) => price,
                PricingModel::Tiered(tiered) => self._calculate_tiered_price(content_id, user, tiered),
                PricingModel::TimeBasedDecay(decay) => self._calculate_time_decay_price(decay),
                PricingModel::DynamicDemand(dynamic) => self._calculate_dynamic_price(content_id, dynamic),
            }
        }
        
        /// Updates dynamic pricing based on recent demand
        fn update_dynamic_pricing(
            ref self: ContractState,
            content_id: u256
        ) -> u256 {
            let mut pricing = self.content_pricing.read(content_id);
            assert(pricing.creator.is_non_zero(), 'Content pricing not found');
            
            match pricing.pricing_model {
                PricingModel::DynamicDemand(mut dynamic) => {
                    let current_time = get_current_time();
                    
                    // Only update if enough time has passed
                    if current_time - dynamic.last_adjustment >= dynamic.adjustment_period {
                        let demand_factor = self._calculate_demand_factor(content_id);
                        let old_price = dynamic.base_price * dynamic.demand_multiplier / 1000; // Assuming multiplier is in basis points
                        
                        // Update demand multiplier based on recent activity
                        dynamic.demand_multiplier = self._adjust_demand_multiplier(demand_factor, dynamic.demand_multiplier);
                        dynamic.last_adjustment = current_time;
                        
                        // Calculate new price
                        let new_price = dynamic.base_price * dynamic.demand_multiplier / 1000;
                        let capped_price = if new_price > dynamic.max_price { dynamic.max_price } else { new_price };
                        
                        // Update pricing model
                        pricing.pricing_model = PricingModel::DynamicDemand(dynamic);
                        pricing.updated_at = current_time;
                        self.content_pricing.write(content_id, pricing);
                        
                        // Emit event
                        self.emit(DynamicPriceAdjusted {
                            content_id,
                            old_price,
                            new_price: capped_price,
                            demand_factor,
                        });
                        
                        capped_price
                    } else {
                        // Return current price without updating
                        let current_price = dynamic.base_price * dynamic.demand_multiplier / 1000;
                        if current_price > dynamic.max_price { dynamic.max_price } else { current_price }
                    }
                },
                _ => {
                    panic!("Content does not use dynamic pricing");
                }
            }
        }
        
        /// Records an access attempt (successful or failed)
        fn record_access_attempt(
            ref self: ContractState,
            content_id: u256,
            user: ContractAddress,
            price_paid: u256,
            success: bool,
            failure_reason: felt252
        ) -> u256 {
            let attempt_id = self.attempt_count.read() + 1;
            self.attempt_count.write(attempt_id);
            
            let attempt = AccessAttempt {
                user,
                content_id,
                timestamp: get_current_time(),
                price_paid,
                success,
                failure_reason,
            };
            
            // Store attempt
            self.access_attempts.write(attempt_id, attempt);
            
            // Add to user's attempt history
            self._add_user_attempt(user, attempt_id);
            
            // Add to content's attempt history
            self._add_content_attempt(content_id, attempt_id);
            
            // Update demand tracking for dynamic pricing
            if success {
                self._update_demand_tracking(content_id);
            }
            
            // Emit event
            self.emit(AccessAttemptRecorded {
                attempt_id,
                user,
                content_id,
                price_paid,
                success,
            });
            
            attempt_id
        }
        
        /// Gets pricing information for content
        fn get_content_pricing(
            self: @ContractState,
            content_id: u256
        ) -> ContentPricing {
            let pricing = self.content_pricing.read(content_id);
            assert(pricing.creator.is_non_zero(), 'Content pricing not found');
            pricing
        }
        
        /// Validates if user can afford current price
        fn can_afford_content(
            self: @ContractState,
            content_id: u256,
            user: ContractAddress,
            available_balance: u256
        ) -> bool {
            let current_price = self.get_current_price(content_id, user);
            available_balance >= current_price
        }
        
        /// Gets access statistics for content
        fn get_access_statistics(
            self: @ContractState,
            content_id: u256,
            time_period: u64
        ) -> (u256, u256, u256) {
            let current_time = get_current_time();
            let cutoff_time = current_time - time_period;
            
            let total_attempts = self.content_attempt_count.read(content_id);
            let mut successful_accesses = 0_u256;
            let mut total_revenue = 0_u256;
            let mut analyzed_attempts = 0_u256;
            
            // Analyze recent attempts
            let mut i = 0;
            while i < total_attempts && analyzed_attempts < 1000 { // Limit to prevent gas issues
                let attempt_id = self.content_attempts.read((content_id, i));
                let attempt = self.access_attempts.read(attempt_id);
                
                if attempt.timestamp >= cutoff_time {
                    analyzed_attempts += 1;
                    if attempt.success {
                        successful_accesses += 1;
                        total_revenue += attempt.price_paid;
                    }
                }
                
                i += 1;
            };
            
            (analyzed_attempts, successful_accesses, total_revenue)
        }
        
        /// Enforces payment failure handling
        fn handle_payment_failure(
            ref self: ContractState,
            content_id: u256,
            user: ContractAddress,
            required_amount: u256,
            available_amount: u256
        ) -> felt252 {
            // Record the failed attempt
            self.record_access_attempt(
                content_id,
                user,
                0,
                false,
                'insufficient_balance'
            );
            
            // Determine action based on how far short the user is
            let shortage = required_amount - available_amount;
            let shortage_percentage = (shortage * 100) / required_amount;
            
            let action_taken = if shortage_percentage > 50 {
                'block_access' // Block if user has less than 50% of required amount
            } else if shortage_percentage > 20 {
                'warn_user' // Warn if user has less than 80% of required amount
            } else {
                'allow_partial' // Allow with partial payment if very close
            };
            
            // Emit event
            self.emit(PaymentFailureHandled {
                user,
                content_id,
                required_amount,
                available_amount,
                action_taken,
            });
            
            action_taken
        }
        
        /// Gets user's access history for content
        fn get_user_access_history(
            self: @ContractState,
            user: ContractAddress,
            content_id: u256,
            limit: u32
        ) -> Array<AccessAttempt> {
            let mut attempts = ArrayTrait::new();
            let total_attempts = self.user_attempt_count.read(user);
            
            // Get most recent attempts up to limit
            let start_index = if total_attempts > limit.into() {
                total_attempts - limit.into()
            } else {
                0
            };
            
            let mut i = start_index;
            while i < total_attempts {
                let attempt_id = self.user_attempts.read((user, i));
                let attempt = self.access_attempts.read(attempt_id);
                
                // Filter by content_id if specified (0 means all content)
                if content_id == 0 || attempt.content_id == content_id {
                    attempts.append(attempt);
                }
                
                i += 1;
            };
            
            attempts
        }
        
        /// Bulk updates pricing for multiple content items
        fn bulk_update_pricing(
            ref self: ContractState,
            content_ids: Array<u256>,
            pricing_models: Array<PricingModel>
        ) -> u32 {
            assert(content_ids.len() == pricing_models.len(), 'Array length mismatch');
            
            let mut success_count = 0_u32;
            let mut failed_count = 0_u32;
            let mut i = 0;
            
            while i < content_ids.len() {
                let content_id = *content_ids.at(i);
                let pricing_model = *pricing_models.at(i);
                
                // Try to update pricing (will fail if unauthorized)
                let result = self.set_content_pricing(content_id, pricing_model);
                if result {
                    success_count += 1;
                } else {
                    failed_count += 1;
                }
                
                i += 1;
            };
            
            // Emit bulk update event
            self.emit(BulkPricingUpdated {
                updated_count: success_count,
                failed_count,
            });
            
            success_count
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Adds attempt to user's history
        fn _add_user_attempt(ref self: ContractState, user: ContractAddress, attempt_id: u256) {
            let count = self.user_attempt_count.read(user);
            self.user_attempts.write((user, count), attempt_id);
            self.user_attempt_count.write(user, count + 1);
        }
        
        /// Adds attempt to content's history
        fn _add_content_attempt(ref self: ContractState, content_id: u256, attempt_id: u256) {
            let count = self.content_attempt_count.read(content_id);
            self.content_attempts.write((content_id, count), attempt_id);
            self.content_attempt_count.write(content_id, count + 1);
        }
        
        /// Updates demand tracking for dynamic pricing
        fn _update_demand_tracking(ref self: ContractState, content_id: u256) {
            let current_time = get_current_time();
            let bucket_size = self.time_bucket_size.read();
            let time_bucket = current_time / bucket_size;
            
            let current_count = self.recent_access_count.read((content_id, time_bucket));
            self.recent_access_count.write((content_id, time_bucket), current_count + 1);
        }
        
        /// Calculates tiered price based on user's access history
        fn _calculate_tiered_price(
            self: @ContractState,
            content_id: u256,
            user: ContractAddress,
            tiered: TieredPricing
        ) -> u256 {
            // Count user's successful accesses to this content
            let user_attempts = self.user_attempt_count.read(user);
            let mut access_count = 0_u256;
            
            let mut i = 0;
            while i < user_attempts && i < 100 { // Limit to prevent gas issues
                let attempt_id = self.user_attempts.read((user, i));
                let attempt = self.access_attempts.read(attempt_id);
                
                if attempt.content_id == content_id && attempt.success {
                    access_count += 1;
                }
                
                i += 1;
            };
            
            // Return price based on tier
            if access_count < tiered.tier1_threshold {
                tiered.tier1_price
            } else if access_count < tiered.tier2_threshold {
                tiered.tier2_price
            } else {
                tiered.tier3_price
            }
        }
        
        /// Calculates time-based decay price
        fn _calculate_time_decay_price(self: @ContractState, decay: TimeDecayPricing) -> u256 {
            let current_time = get_current_time();
            let time_elapsed = current_time - decay.creation_time;
            let days_elapsed = time_elapsed / 86400; // Convert to days
            
            // Calculate decayed price
            let decay_amount = decay.decay_rate * days_elapsed.into();
            let decayed_price = if decay.initial_price > decay_amount {
                decay.initial_price - decay_amount
            } else {
                decay.minimum_price
            };
            
            // Ensure price doesn't go below minimum
            if decayed_price < decay.minimum_price {
                decay.minimum_price
            } else {
                decayed_price
            }
        }
        
        /// Calculates dynamic price based on recent demand
        fn _calculate_dynamic_price(self: @ContractState, content_id: u256, dynamic: DynamicPricing) -> u256 {
            let base_price = dynamic.base_price * dynamic.demand_multiplier / 1000;
            if base_price > dynamic.max_price {
                dynamic.max_price
            } else {
                base_price
            }
        }
        
        /// Calculates demand factor for dynamic pricing
        fn _calculate_demand_factor(self: @ContractState, content_id: u256) -> u256 {
            let current_time = get_current_time();
            let bucket_size = self.time_bucket_size.read();
            let current_bucket = current_time / bucket_size;
            
            // Look at last few time buckets to calculate demand
            let mut total_accesses = 0_u256;
            let buckets_to_check = 5; // Check last 5 time buckets
            
            let mut i = 0;
            while i < buckets_to_check {
                let bucket = current_bucket - i.into();
                let accesses = self.recent_access_count.read((content_id, bucket));
                total_accesses += accesses;
                i += 1;
            };
            
            // Return demand factor (higher = more demand)
            total_accesses
        }
        
        /// Adjusts demand multiplier based on demand factor
        fn _adjust_demand_multiplier(self: @ContractState, demand_factor: u256, current_multiplier: u256) -> u256 {
            let max_multiplier = self.max_dynamic_multiplier.read();
            
            // Simple demand-based adjustment
            let adjustment = if demand_factor > 10 {
                50 // Increase multiplier by 5% if high demand
            } else if demand_factor < 2 {
                -25 // Decrease multiplier by 2.5% if low demand
            } else {
                0 // No change for moderate demand
            };
            
            let new_multiplier = if adjustment > 0 {
                current_multiplier + adjustment.try_into().unwrap()
            } else if adjustment < 0 {
                let decrease = (-adjustment).try_into().unwrap();
                if current_multiplier > decrease {
                    current_multiplier - decrease
                } else {
                    500 // Minimum multiplier (50%)
                }
            } else {
                current_multiplier
            };
            
            // Cap at maximum multiplier
            if new_multiplier > max_multiplier {
                max_multiplier
            } else {
                new_multiplier
            }
        }
    }
}