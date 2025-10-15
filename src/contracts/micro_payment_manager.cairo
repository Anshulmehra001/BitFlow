use starknet::{ContractAddress, get_caller_address};
use crate::interfaces::micro_payment::{IMicroPaymentManager, MicroPayment, ContentAccess, UserBalance};
use crate::interfaces::stream_manager::{IStreamManagerDispatcher, IStreamManagerDispatcherTrait};
use crate::types::BitFlowError;
use crate::utils::time::get_current_time;
// use crate::utils::validation::validate_address; // Not needed for this implementation

#[starknet::contract]
pub mod MicroPaymentManager {
    use super::*;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    #[storage]
    struct Storage {
        // Core payment tracking
        payments: Map<u256, MicroPayment>,
        payment_count: u256,
        
        // Content management
        content: Map<u256, ContentAccess>,
        creator_content: Map<(ContractAddress, u256), u256>, // (creator, index) -> content_id
        creator_content_count: Map<ContractAddress, u256>,
        
        // User balance tracking
        user_balances: Map<ContractAddress, UserBalance>,
        
        // Payment history tracking
        user_payments: Map<(ContractAddress, u256), u256>, // (user, index) -> payment_id
        user_payment_count: Map<ContractAddress, u256>,
        
        // Stream manager reference
        stream_manager: ContractAddress,
        
        // Contract owner
        owner: ContractAddress,
        
        // Minimum payment amount (to prevent spam)
        min_payment_amount: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MicroPaymentProcessed: MicroPaymentProcessed,
        ContentRegistered: ContentRegistered,
        ContentPriceUpdated: ContentPriceUpdated,
        ContentDeactivated: ContentDeactivated,
        LowBalanceAlert: LowBalanceAlert,
        PaymentFailed: PaymentFailed,
        BalanceReserved: BalanceReserved,
        BalanceReleased: BalanceReleased,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MicroPaymentProcessed {
        #[key]
        pub payment_id: u256,
        #[key]
        pub payer: ContractAddress,
        #[key]
        pub content_creator: ContractAddress,
        pub content_id: u256,
        pub amount: u256,
        pub stream_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContentRegistered {
        #[key]
        pub content_id: u256,
        #[key]
        pub creator: ContractAddress,
        pub price_per_access: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContentPriceUpdated {
        #[key]
        pub content_id: u256,
        #[key]
        pub creator: ContractAddress,
        pub old_price: u256,
        pub new_price: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContentDeactivated {
        #[key]
        pub content_id: u256,
        #[key]
        pub creator: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LowBalanceAlert {
        #[key]
        pub user: ContractAddress,
        pub current_balance: u256,
        pub threshold: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PaymentFailed {
        #[key]
        pub user: ContractAddress,
        pub content_id: u256,
        pub required_amount: u256,
        pub available_balance: u256,
        pub reason: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BalanceReserved {
        #[key]
        pub user: ContractAddress,
        pub amount: u256,
        pub total_reserved: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BalanceReleased {
        #[key]
        pub user: ContractAddress,
        pub amount: u256,
        pub remaining_reserved: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        stream_manager: ContractAddress,
        min_payment_amount: u256
    ) {
        self.owner.write(owner);
        self.stream_manager.write(stream_manager);
        self.payment_count.write(0);
        self.min_payment_amount.write(min_payment_amount);
    }

    #[abi(embed_v0)]
    impl MicroPaymentManagerImpl of IMicroPaymentManager<ContractState> {
        /// Processes a micro-payment for content access
        fn process_micro_payment(
            ref self: ContractState,
            content_id: u256,
            stream_id: u256
        ) -> u256 {
            let caller = get_caller_address();
            
            // Get content information
            let mut content = self.content.read(content_id);
            assert(content.creator.is_non_zero(), 'Content not found');
            assert(content.is_active, 'Content not active');
            assert(content.price_per_access >= self.min_payment_amount.read(), 'Amount too small');
            
            // Check if user can afford the payment
            let available_balance = self._calculate_user_available_balance(caller);
            let user_balance = self.user_balances.read(caller);
            let total_available = available_balance - user_balance.reserved_balance;
            
            if total_available < content.price_per_access {
                // Emit payment failed event
                self.emit(PaymentFailed {
                    user: caller,
                    content_id,
                    required_amount: content.price_per_access,
                    available_balance: total_available,
                    reason: 'Insufficient balance',
                });
                
                // Check if balance is low and notify
                self._check_and_notify_low_balance(caller, total_available);
                
                panic!("Insufficient balance for payment");
            }
            
            // Create payment record
            let payment_id = self.payment_count.read() + 1;
            self.payment_count.write(payment_id);
            
            let payment = MicroPayment {
                id: payment_id,
                payer: caller,
                content_creator: content.creator,
                content_id,
                amount: content.price_per_access,
                timestamp: get_current_time(),
                stream_id,
            };
            
            // Store payment
            self.payments.write(payment_id, payment);
            
            // Add to user's payment history
            self._add_user_payment(caller, payment_id);
            
            // Update content statistics
            content.total_accesses += 1;
            content.total_revenue += content.price_per_access;
            self.content.write(content_id, content);
            
            // Update user balance (deduct from available)
            let mut updated_balance = self.user_balances.read(caller);
            updated_balance.available_balance = total_available - content.price_per_access;
            self.user_balances.write(caller, updated_balance);
            
            // Check for low balance after payment
            self._check_and_notify_low_balance(caller, updated_balance.available_balance);
            
            // Emit success event
            self.emit(MicroPaymentProcessed {
                payment_id,
                payer: caller,
                content_creator: content.creator,
                content_id,
                amount: content.price_per_access,
                stream_id,
            });
            
            payment_id
        }
        
        /// Registers new content with pricing
        fn register_content(
            ref self: ContractState,
            content_id: u256,
            price_per_access: u256
        ) -> bool {
            let caller = get_caller_address();
            
            // Validate inputs
            assert(content_id > 0, 'Invalid content ID');
            assert(price_per_access >= self.min_payment_amount.read(), 'Price too low');
            
            // Check if content already exists
            let existing_content = self.content.read(content_id);
            assert(existing_content.creator.is_zero(), 'Content already exists');
            
            // Create content record
            let content = ContentAccess {
                content_id,
                creator: caller,
                price_per_access,
                is_active: true,
                total_accesses: 0,
                total_revenue: 0,
            };
            
            // Store content
            self.content.write(content_id, content);
            
            // Add to creator's content list
            self._add_creator_content(caller, content_id);
            
            // Emit event
            self.emit(ContentRegistered {
                content_id,
                creator: caller,
                price_per_access,
            });
            
            true
        }
        
        /// Updates content pricing
        fn update_content_price(
            ref self: ContractState,
            content_id: u256,
            new_price: u256
        ) -> bool {
            let caller = get_caller_address();
            let mut content = self.content.read(content_id);
            
            // Validate content exists and caller is creator
            assert(content.creator.is_non_zero(), 'Content not found');
            assert(content.creator == caller, 'Unauthorized access');
            assert(new_price >= self.min_payment_amount.read(), 'Price too low');
            
            let old_price = content.price_per_access;
            content.price_per_access = new_price;
            self.content.write(content_id, content);
            
            // Emit event
            self.emit(ContentPriceUpdated {
                content_id,
                creator: caller,
                old_price,
                new_price,
            });
            
            true
        }
        
        /// Deactivates content (prevents new accesses)
        fn deactivate_content(
            ref self: ContractState,
            content_id: u256
        ) -> bool {
            let caller = get_caller_address();
            let mut content = self.content.read(content_id);
            
            // Validate content exists and caller is creator
            assert(content.creator.is_non_zero(), 'Content not found');
            assert(content.creator == caller, 'Unauthorized access');
            
            content.is_active = false;
            self.content.write(content_id, content);
            
            // Emit event
            self.emit(ContentDeactivated {
                content_id,
                creator: caller,
            });
            
            true
        }
        
        /// Checks if user has sufficient balance for content access
        fn can_access_content(
            self: @ContractState,
            user: ContractAddress,
            content_id: u256
        ) -> bool {
            let content = self.content.read(content_id);
            if content.creator.is_zero() || !content.is_active {
                return false;
            }
            
            let available_balance = self._calculate_user_available_balance(user);
            let user_balance = self.user_balances.read(user);
            let total_available = available_balance - user_balance.reserved_balance;
            
            total_available >= content.price_per_access
        }
        
        /// Gets content information and pricing
        fn get_content_info(
            self: @ContractState,
            content_id: u256
        ) -> ContentAccess {
            let content = self.content.read(content_id);
            assert(content.creator.is_non_zero(), 'Content not found');
            content
        }
        
        /// Gets user's current balance information
        fn get_user_balance(
            self: @ContractState,
            user: ContractAddress
        ) -> UserBalance {
            let mut balance = self.user_balances.read(user);
            
            // Update available balance from streams
            balance.available_balance = self._calculate_user_available_balance(user);
            
            balance
        }
        
        /// Sets low balance threshold for notifications
        fn set_low_balance_threshold(
            ref self: ContractState,
            threshold: u256
        ) -> bool {
            let caller = get_caller_address();
            let mut balance = self.user_balances.read(caller);
            
            balance.low_balance_threshold = threshold;
            self.user_balances.write(caller, balance);
            
            true
        }
        
        /// Checks if user balance is below threshold
        fn is_balance_low(
            self: @ContractState,
            user: ContractAddress
        ) -> bool {
            let balance = self.user_balances.read(user);
            let available = self._calculate_user_available_balance(user);
            let total_available = available - balance.reserved_balance;
            
            balance.low_balance_threshold > 0 && total_available < balance.low_balance_threshold
        }
        
        /// Gets payment history for a user
        fn get_payment_history(
            self: @ContractState,
            user: ContractAddress,
            limit: u32
        ) -> Array<MicroPayment> {
            let mut payments = ArrayTrait::new();
            let total_payments = self.user_payment_count.read(user);
            
            // Get most recent payments up to limit
            let start_index = if total_payments > limit.into() {
                total_payments - limit.into()
            } else {
                0
            };
            
            let mut i = start_index;
            while i < total_payments {
                let payment_id = self.user_payments.read((user, i));
                let payment = self.payments.read(payment_id);
                payments.append(payment);
                i += 1;
            };
            
            payments
        }
        
        /// Gets content access statistics for creators
        fn get_creator_content(
            self: @ContractState,
            creator: ContractAddress
        ) -> Array<u256> {
            let mut content_ids = ArrayTrait::new();
            let count = self.creator_content_count.read(creator);
            
            let mut i = 0;
            while i < count {
                let content_id = self.creator_content.read((creator, i));
                content_ids.append(content_id);
                i += 1;
            };
            
            content_ids
        }
        
        /// Calculates available balance from active streams
        fn calculate_available_balance(
            self: @ContractState,
            user: ContractAddress
        ) -> u256 {
            self._calculate_user_available_balance(user)
        }
        
        /// Reserves balance for upcoming payments
        fn reserve_balance(
            ref self: ContractState,
            user: ContractAddress,
            amount: u256
        ) -> bool {
            let available_balance = self._calculate_user_available_balance(user);
            let mut user_balance = self.user_balances.read(user);
            
            let total_available = available_balance - user_balance.reserved_balance;
            assert(total_available >= amount, 'Insufficient balance to reserve');
            
            user_balance.reserved_balance += amount;
            self.user_balances.write(user, user_balance);
            
            // Emit event
            self.emit(BalanceReserved {
                user,
                amount,
                total_reserved: user_balance.reserved_balance,
            });
            
            true
        }
        
        /// Releases reserved balance
        fn release_reserved_balance(
            ref self: ContractState,
            user: ContractAddress,
            amount: u256
        ) -> bool {
            let mut user_balance = self.user_balances.read(user);
            assert(user_balance.reserved_balance >= amount, 'Insufficient reserved balance');
            
            user_balance.reserved_balance -= amount;
            self.user_balances.write(user, user_balance);
            
            // Emit event
            self.emit(BalanceReleased {
                user,
                amount,
                remaining_reserved: user_balance.reserved_balance,
            });
            
            true
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Adds a payment to user's payment history
        fn _add_user_payment(ref self: ContractState, user: ContractAddress, payment_id: u256) {
            let count = self.user_payment_count.read(user);
            self.user_payments.write((user, count), payment_id);
            self.user_payment_count.write(user, count + 1);
        }
        
        /// Adds content to creator's content list
        fn _add_creator_content(ref self: ContractState, creator: ContractAddress, content_id: u256) {
            let count = self.creator_content_count.read(creator);
            self.creator_content.write((creator, count), content_id);
            self.creator_content_count.write(creator, count + 1);
        }
        
        /// Calculates user's available balance from all streams
        fn _calculate_user_available_balance(self: @ContractState, user: ContractAddress) -> u256 {
            let stream_manager = IStreamManagerDispatcher { 
                contract_address: self.stream_manager.read() 
            };
            
            // Get all user streams
            let stream_ids = stream_manager.get_user_streams(user);
            let mut total_balance = 0_u256;
            
            let mut i = 0;
            while i < stream_ids.len() {
                let stream_id = *stream_ids.at(i);
                
                // Only count streams where user is the sender (has balance to spend)
                let stream = stream_manager.get_stream(stream_id);
                if stream.sender == user && stream_manager.is_stream_active(stream_id) {
                    let stream_balance = stream_manager.get_stream_balance(stream_id);
                    total_balance += stream_balance;
                }
                
                i += 1;
            };
            
            total_balance
        }
        
        /// Checks if balance is low and sends notification if needed
        fn _check_and_notify_low_balance(ref self: ContractState, user: ContractAddress, current_balance: u256) {
            let mut user_balance = self.user_balances.read(user);
            
            if user_balance.low_balance_threshold > 0 && current_balance < user_balance.low_balance_threshold {
                let current_time = get_current_time();
                
                // Only notify once per hour to avoid spam
                let notification_cooldown = 3600_u64; // 1 hour
                if current_time - user_balance.last_notification > notification_cooldown {
                    user_balance.last_notification = current_time;
                    self.user_balances.write(user, user_balance);
                    
                    self.emit(LowBalanceAlert {
                        user,
                        current_balance,
                        threshold: user_balance.low_balance_threshold,
                    });
                }
            }
        }
    }
}