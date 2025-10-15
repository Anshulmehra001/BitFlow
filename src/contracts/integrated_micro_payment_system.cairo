use starknet::{ContractAddress, get_caller_address};
use crate::interfaces::micro_payment::{IMicroPaymentManagerDispatcher, IMicroPaymentManagerDispatcherTrait};
use crate::interfaces::content_pricing::{IContentPricingManagerDispatcher, IContentPricingManagerDispatcherTrait, PricingModel};
use crate::interfaces::stream_manager::{IStreamManagerDispatcher, IStreamManagerDispatcherTrait};
use crate::types::BitFlowError;
use crate::utils::time::get_current_time;

/// Integrated micro-payment system that combines payment processing with flexible pricing
#[starknet::contract]
pub mod IntegratedMicroPaymentSystem {
    use super::*;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    #[storage]
    struct Storage {
        // Component contract addresses
        micro_payment_manager: ContractAddress,
        content_pricing_manager: ContractAddress,
        stream_manager: ContractAddress,
        
        // System settings
        owner: ContractAddress,
        auto_pricing_enabled: bool,
        
        // Access control
        authorized_creators: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ContentAccessGranted: ContentAccessGranted,
        ContentAccessDenied: ContentAccessDenied,
        PricingModelUpdated: PricingModelUpdated,
        CreatorAuthorized: CreatorAuthorized,
        CreatorDeauthorized: CreatorDeauthorized,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContentAccessGranted {
        #[key]
        pub user: ContractAddress,
        #[key]
        pub content_id: u256,
        #[key]
        pub creator: ContractAddress,
        pub price_paid: u256,
        pub payment_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContentAccessDenied {
        #[key]
        pub user: ContractAddress,
        #[key]
        pub content_id: u256,
        pub required_price: u256,
        pub available_balance: u256,
        pub reason: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PricingModelUpdated {
        #[key]
        pub content_id: u256,
        #[key]
        pub creator: ContractAddress,
        pub pricing_type: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CreatorAuthorized {
        #[key]
        pub creator: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CreatorDeauthorized {
        #[key]
        pub creator: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        micro_payment_manager: ContractAddress,
        content_pricing_manager: ContractAddress,
        stream_manager: ContractAddress
    ) {
        self.owner.write(owner);
        self.micro_payment_manager.write(micro_payment_manager);
        self.content_pricing_manager.write(content_pricing_manager);
        self.stream_manager.write(stream_manager);
        self.auto_pricing_enabled.write(true);
    }

    #[abi(embed_v0)]
    impl IntegratedMicroPaymentSystemImpl of IIntegratedMicroPaymentSystem<ContractState> {
        /// Attempts to access content with automatic pricing and payment
        /// @param content_id The unique identifier of the content
        /// @param stream_id The stream to use for payment
        /// @return success True if access was granted
        fn access_content(
            ref self: ContractState,
            content_id: u256,
            stream_id: u256
        ) -> bool {
            let caller = get_caller_address();
            
            // Get pricing manager
            let pricing_manager = IContentPricingManagerDispatcher {
                contract_address: self.content_pricing_manager.read()
            };
            
            // Get micro payment manager
            let payment_manager = IMicroPaymentManagerDispatcher {
                contract_address: self.micro_payment_manager.read()
            };
            
            // Get current price for the user
            let current_price = pricing_manager.get_current_price(content_id, caller);
            
            // Check if user can afford the content
            let available_balance = payment_manager.calculate_available_balance(caller);
            let user_balance = payment_manager.get_user_balance(caller);
            let total_available = available_balance - user_balance.reserved_balance;
            
            if total_available < current_price {
                // Record failed access attempt
                pricing_manager.record_access_attempt(
                    content_id,
                    caller,
                    0,
                    false,
                    'insufficient_balance'
                );
                
                // Handle payment failure
                let action = pricing_manager.handle_payment_failure(
                    content_id,
                    caller,
                    current_price,
                    total_available
                );
                
                // Emit access denied event
                self.emit(ContentAccessDenied {
                    user: caller,
                    content_id,
                    required_price: current_price,
                    available_balance: total_available,
                    reason: action,
                });
                
                return false;
            }
            
            // Process the micro payment
            let payment_id = payment_manager.process_micro_payment(content_id, stream_id);
            
            // Record successful access attempt
            pricing_manager.record_access_attempt(
                content_id,
                caller,
                current_price,
                true,
                ''
            );
            
            // Update dynamic pricing if enabled and applicable
            if self.auto_pricing_enabled.read() {
                self._maybe_update_dynamic_pricing(content_id);
            }
            
            // Get content info for creator address
            let content_info = payment_manager.get_content_info(content_id);
            
            // Emit access granted event
            self.emit(ContentAccessGranted {
                user: caller,
                content_id,
                creator: content_info.creator,
                price_paid: current_price,
                payment_id,
            });
            
            true
        }
        
        /// Sets up content with pricing model and registers it for micro-payments
        /// @param content_id The unique identifier of the content
        /// @param pricing_model The pricing model to use
        /// @return success True if setup was successful
        fn setup_content_with_pricing(
            ref self: ContractState,
            content_id: u256,
            pricing_model: PricingModel
        ) -> bool {
            let caller = get_caller_address();
            
            // Check if creator is authorized (if authorization is enabled)
            // For now, allow all creators
            
            // Get base price from pricing model
            let base_price = match pricing_model {
                PricingModel::Fixed(price) => price,
                PricingModel::Tiered(tiered) => tiered.tier1_price,
                PricingModel::TimeBasedDecay(decay) => decay.initial_price,
                PricingModel::DynamicDemand(dynamic) => dynamic.base_price,
            };
            
            // Register content in micro payment manager
            let payment_manager = IMicroPaymentManagerDispatcher {
                contract_address: self.micro_payment_manager.read()
            };
            let payment_success = payment_manager.register_content(content_id, base_price);
            assert(payment_success, 'Payment registration failed');
            
            // Set pricing model in pricing manager
            let pricing_manager = IContentPricingManagerDispatcher {
                contract_address: self.content_pricing_manager.read()
            };
            let pricing_success = pricing_manager.set_content_pricing(content_id, pricing_model);
            assert(pricing_success, 'Pricing setup failed');
            
            // Emit event
            let pricing_type = match pricing_model {
                PricingModel::Fixed(_) => 'fixed',
                PricingModel::Tiered(_) => 'tiered',
                PricingModel::TimeBasedDecay(_) => 'time_decay',
                PricingModel::DynamicDemand(_) => 'dynamic',
            };
            
            self.emit(PricingModelUpdated {
                content_id,
                creator: caller,
                pricing_type,
            });
            
            true
        }
        
        /// Gets comprehensive content information including pricing and statistics
        /// @param content_id The unique identifier of the content
        /// @return (base_info, current_price, access_stats) Comprehensive content information
        fn get_content_info_comprehensive(
            self: @ContractState,
            content_id: u256
        ) -> (ContentAccess, u256, (u256, u256, u256)) {
            let payment_manager = IMicroPaymentManagerDispatcher {
                contract_address: self.micro_payment_manager.read()
            };
            let pricing_manager = IContentPricingManagerDispatcher {
                contract_address: self.content_pricing_manager.read()
            };
            
            let caller = get_caller_address();
            
            // Get basic content info
            let base_info = payment_manager.get_content_info(content_id);
            
            // Get current price for caller
            let current_price = pricing_manager.get_current_price(content_id, caller);
            
            // Get access statistics for last 24 hours
            let access_stats = pricing_manager.get_access_statistics(content_id, 86400);
            
            (base_info, current_price, access_stats)
        }
        
        /// Checks if user can access content (considering both balance and pricing)
        /// @param user The user to check
        /// @param content_id The content to check access for
        /// @return (can_access, current_price, available_balance) Access information
        fn check_content_access(
            self: @ContractState,
            user: ContractAddress,
            content_id: u256
        ) -> (bool, u256, u256) {
            let payment_manager = IMicroPaymentManagerDispatcher {
                contract_address: self.micro_payment_manager.read()
            };
            let pricing_manager = IContentPricingManagerDispatcher {
                contract_address: self.content_pricing_manager.read()
            };
            
            // Get current price
            let current_price = pricing_manager.get_current_price(content_id, user);
            
            // Get available balance
            let available_balance = payment_manager.calculate_available_balance(user);
            let user_balance = payment_manager.get_user_balance(user);
            let total_available = available_balance - user_balance.reserved_balance;
            
            // Check if user can afford
            let can_access = pricing_manager.can_afford_content(content_id, user, total_available);
            
            (can_access, current_price, total_available)
        }
        
        /// Authorizes a creator (admin only)
        /// @param creator The creator to authorize
        /// @return success True if authorization was successful
        fn authorize_creator(
            ref self: ContractState,
            creator: ContractAddress
        ) -> bool {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Unauthorized access');
            
            self.authorized_creators.write(creator, true);
            
            self.emit(CreatorAuthorized { creator });
            
            true
        }
        
        /// Deauthorizes a creator (admin only)
        /// @param creator The creator to deauthorize
        /// @return success True if deauthorization was successful
        fn deauthorize_creator(
            ref self: ContractState,
            creator: ContractAddress
        ) -> bool {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Unauthorized access');
            
            self.authorized_creators.write(creator, false);
            
            self.emit(CreatorDeauthorized { creator });
            
            true
        }
        
        /// Enables or disables automatic pricing updates
        /// @param enabled Whether to enable automatic pricing
        /// @return success True if setting was updated
        fn set_auto_pricing(
            ref self: ContractState,
            enabled: bool
        ) -> bool {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Unauthorized access');
            
            self.auto_pricing_enabled.write(enabled);
            
            true
        }
        
        /// Gets system configuration
        /// @return (auto_pricing_enabled, component_addresses) System configuration
        fn get_system_config(
            self: @ContractState
        ) -> (bool, (ContractAddress, ContractAddress, ContractAddress)) {
            let auto_pricing = self.auto_pricing_enabled.read();
            let components = (
                self.micro_payment_manager.read(),
                self.content_pricing_manager.read(),
                self.stream_manager.read()
            );
            
            (auto_pricing, components)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Maybe updates dynamic pricing if content uses dynamic pricing model
        fn _maybe_update_dynamic_pricing(ref self: ContractState, content_id: u256) {
            let pricing_manager = IContentPricingManagerDispatcher {
                contract_address: self.content_pricing_manager.read()
            };
            
            // Try to update dynamic pricing (will only work if content uses dynamic pricing)
            // We don't panic if it fails, just silently continue
            let content_pricing = pricing_manager.get_content_pricing(content_id);
            match content_pricing.pricing_model {
                PricingModel::DynamicDemand(_) => {
                    pricing_manager.update_dynamic_pricing(content_id);
                },
                _ => {
                    // Do nothing for non-dynamic pricing models
                }
            }
        }
    }
}

#[starknet::interface]
pub trait IIntegratedMicroPaymentSystem<TContractState> {
    fn access_content(ref self: TContractState, content_id: u256, stream_id: u256) -> bool;
    fn setup_content_with_pricing(ref self: TContractState, content_id: u256, pricing_model: PricingModel) -> bool;
    fn get_content_info_comprehensive(self: @TContractState, content_id: u256) -> (ContentAccess, u256, (u256, u256, u256));
    fn check_content_access(self: @TContractState, user: ContractAddress, content_id: u256) -> (bool, u256, u256);
    fn authorize_creator(ref self: TContractState, creator: ContractAddress) -> bool;
    fn deauthorize_creator(ref self: TContractState, creator: ContractAddress) -> bool;
    fn set_auto_pricing(ref self: TContractState, enabled: bool) -> bool;
    fn get_system_config(self: @TContractState) -> (bool, (ContractAddress, ContractAddress, ContractAddress));
}

// Import ContentAccess from micro_payment interface
use crate::interfaces::micro_payment::ContentAccess;