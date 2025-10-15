use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use crate::interfaces::subscription_manager::ISubscriptionManager;
use crate::interfaces::stream_manager::{IStreamManagerDispatcher, IStreamManagerDispatcherTrait};
use crate::types::{Subscription, SubscriptionStatus, BitFlowError};
use crate::utils::validation::{validate_subscription_parameters, validate_subscription_creation, validate_subscription_lifecycle};

#[derive(Drop, Serde, starknet::Store)]
pub struct SubscriptionPlan {
    pub id: u256,
    pub creator: ContractAddress,
    pub price: u256,
    pub interval: u64,
    pub max_subscribers: u32,
    pub current_subscribers: u32,
    pub metadata: felt252,
    pub is_active: bool,
    pub created_at: u64,
}

#[starknet::contract]
pub mod SubscriptionManager {
    use super::*;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    #[storage]
    struct Storage {
        // Core state
        next_plan_id: u256,
        next_subscription_id: u256,
        stream_manager: ContractAddress,
        
        // Plan storage
        plans: Map<u256, SubscriptionPlan>,
        
        // Subscription storage
        subscriptions: Map<u256, Subscription>,
        
        // User mappings
        user_subscriptions: Map<(ContractAddress, u256), u256>, // (user, index) -> subscription_id
        user_subscription_count: Map<ContractAddress, u256>,
        plan_subscriptions: Map<(u256, u256), u256>, // (plan_id, index) -> subscription_id
        plan_subscription_count: Map<u256, u256>,
        
        // Analytics storage
        plan_total_revenue: Map<u256, u256>,
        plan_total_subscribers: Map<u256, u32>,
        
        // Detailed analytics
        plan_total_renewals: Map<u256, u32>,
        plan_auto_renewals: Map<u256, u32>,
        plan_manual_renewals: Map<u256, u32>,
        plan_cancelled_count: Map<u256, u32>,
        plan_total_duration: Map<u256, u64>, // Sum of all subscription durations
        
        // Global analytics
        total_plans_created: u256,
        total_subscriptions_created: u256,
        global_total_revenue: u256,
        
        // Access control
        owner: ContractAddress,
        paused: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PlanCreated: PlanCreated,
        SubscriptionCreated: SubscriptionCreated,
        SubscriptionCancelled: SubscriptionCancelled,
        SubscriptionPaused: SubscriptionPaused,
        SubscriptionResumed: SubscriptionResumed,
        SubscriptionRenewed: SubscriptionRenewed,
        PlanUpdated: PlanUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PlanCreated {
        pub plan_id: u256,
        pub creator: ContractAddress,
        pub price: u256,
        pub interval: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SubscriptionCreated {
        pub subscription_id: u256,
        pub plan_id: u256,
        pub subscriber: ContractAddress,
        pub stream_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SubscriptionCancelled {
        pub subscription_id: u256,
        pub subscriber: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SubscriptionPaused {
        pub subscription_id: u256,
        pub subscriber: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SubscriptionResumed {
        pub subscription_id: u256,
        pub subscriber: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SubscriptionRenewed {
        pub subscription_id: u256,
        pub subscriber: ContractAddress,
        pub new_end_time: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PlanUpdated {
        pub plan_id: u256,
        pub new_price: u256,
        pub new_max_subscribers: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, stream_manager: ContractAddress, owner: ContractAddress) {
        self.stream_manager.write(stream_manager);
        self.owner.write(owner);
        self.next_plan_id.write(1);
        self.next_subscription_id.write(1);
        self.paused.write(false);
        self.total_plans_created.write(0);
        self.total_subscriptions_created.write(0);
        self.global_total_revenue.write(0);
    }

    #[abi(embed_v0)]
    impl SubscriptionManagerImpl of ISubscriptionManager<ContractState> {
        fn create_subscription_plan(
            ref self: ContractState,
            price: u256,
            interval: u64,
            max_subscribers: u32,
            metadata: felt252
        ) -> u256 {
            self._assert_not_paused();
            
            // Validate parameters using validation utils
            validate_subscription_parameters(price, interval, max_subscribers).unwrap();
            
            let caller = get_caller_address();
            let plan_id = self.next_plan_id.read();
            let current_time = get_block_timestamp();
            
            let plan = SubscriptionPlan {
                id: plan_id,
                creator: caller,
                price,
                interval,
                max_subscribers,
                current_subscribers: 0,
                metadata,
                is_active: true,
                created_at: current_time,
            };
            
            self.plans.entry(plan_id).write(plan);
            self.next_plan_id.write(plan_id + 1);
            
            // Update global analytics
            let total_plans = self.total_plans_created.read();
            self.total_plans_created.write(total_plans + 1);
            
            self.emit(PlanCreated { plan_id, creator: caller, price, interval });
            
            plan_id
        }

        fn subscribe(
            ref self: ContractState,
            plan_id: u256,
            duration: u64,
            auto_renew: bool
        ) -> u256 {
            self._assert_not_paused();
            
            let caller = get_caller_address();
            let mut plan = self.plans.entry(plan_id).read();
            let current_time = get_block_timestamp();
            
            // Validate plan exists and is active
            assert(plan.is_active, 'Plan is not active');
            assert(plan.current_subscribers < plan.max_subscribers, 'Plan is full');
            
            // Validate subscription creation parameters
            validate_subscription_creation(caller, plan.creator, duration, current_time).unwrap();
            
            let subscription_id = self.next_subscription_id.read();
            let current_time = get_block_timestamp();
            let end_time = current_time + (duration * plan.interval);
            let total_amount = plan.price * duration.into();
            
            // Create payment stream for the subscription
            let stream_manager = IStreamManagerDispatcher { contract_address: self.stream_manager.read() };
            let stream_id = stream_manager.create_stream(
                plan.creator,
                total_amount,
                plan.price / plan.interval.into(), // Rate per second
                duration * plan.interval
            );
            
            let subscription = Subscription {
                id: subscription_id,
                plan_id,
                subscriber: caller,
                provider: plan.creator,
                stream_id,
                start_time: current_time,
                end_time,
                auto_renew,
                status: SubscriptionStatus::Active,
            };
            
            // Update storage
            self.subscriptions.entry(subscription_id).write(subscription);
            self._add_user_subscription(caller, subscription_id);
            self._add_plan_subscription(plan_id, subscription_id);
            
            // Update plan subscriber count
            plan.current_subscribers += 1;
            self.plans.entry(plan_id).write(plan);
            
            // Update analytics
            let current_revenue = self.plan_total_revenue.entry(plan_id).read();
            self.plan_total_revenue.entry(plan_id).write(current_revenue + total_amount);
            
            let total_subs = self.plan_total_subscribers.entry(plan_id).read();
            self.plan_total_subscribers.entry(plan_id).write(total_subs + 1);
            
            // Update global analytics
            let global_revenue = self.global_total_revenue.read();
            self.global_total_revenue.write(global_revenue + total_amount);
            
            let total_subscriptions = self.total_subscriptions_created.read();
            self.total_subscriptions_created.write(total_subscriptions + 1);
            
            // Track subscription duration for analytics
            let plan_duration = self.plan_total_duration.entry(plan_id).read();
            self.plan_total_duration.entry(plan_id).write(plan_duration + (duration * plan.interval));
            
            self.next_subscription_id.write(subscription_id + 1);
            
            self.emit(SubscriptionCreated { subscription_id, plan_id, subscriber: caller, stream_id });
            
            subscription_id
        }

        fn cancel_subscription(ref self: ContractState, subscription_id: u256) -> bool {
            self._assert_not_paused();
            
            let caller = get_caller_address();
            let mut subscription = self.subscriptions.entry(subscription_id).read();
            
            // Validate subscription exists and caller has permission
            assert(subscription.subscriber == caller || subscription.provider == caller, 'Unauthorized');
            assert(subscription.status == SubscriptionStatus::Active || subscription.status == SubscriptionStatus::Paused, 'Cannot cancel subscription');
            
            // Cancel the underlying stream
            let stream_manager = IStreamManagerDispatcher { contract_address: self.stream_manager.read() };
            stream_manager.cancel_stream(subscription.stream_id);
            
            // Update subscription status
            subscription.status = SubscriptionStatus::Cancelled;
            self.subscriptions.entry(subscription_id).write(subscription);
            
            // Update plan subscriber count
            let mut plan = self.plans.entry(subscription.plan_id).read();
            plan.current_subscribers -= 1;
            self.plans.entry(subscription.plan_id).write(plan);
            
            // Update cancellation analytics
            let cancelled_count = self.plan_cancelled_count.entry(subscription.plan_id).read();
            self.plan_cancelled_count.entry(subscription.plan_id).write(cancelled_count + 1);
            
            self.emit(SubscriptionCancelled { subscription_id, subscriber: subscription.subscriber });
            
            true
        }

        fn pause_subscription(ref self: ContractState, subscription_id: u256) -> bool {
            self._assert_not_paused();
            
            let caller = get_caller_address();
            let mut subscription = self.subscriptions.entry(subscription_id).read();
            
            // Validate subscription exists and caller has permission
            assert(subscription.subscriber == caller, 'Unauthorized');
            assert(subscription.status == SubscriptionStatus::Active, 'Subscription not active');
            
            // Pause the underlying stream
            let stream_manager = IStreamManagerDispatcher { contract_address: self.stream_manager.read() };
            stream_manager.pause_stream(subscription.stream_id);
            
            // Update subscription status
            subscription.status = SubscriptionStatus::Paused;
            self.subscriptions.entry(subscription_id).write(subscription);
            
            self.emit(SubscriptionPaused { subscription_id, subscriber: subscription.subscriber });
            
            true
        }

        fn resume_subscription(ref self: ContractState, subscription_id: u256) -> bool {
            self._assert_not_paused();
            
            let caller = get_caller_address();
            let mut subscription = self.subscriptions.entry(subscription_id).read();
            
            // Validate subscription exists and caller has permission
            assert(subscription.subscriber == caller, 'Unauthorized');
            assert(subscription.status == SubscriptionStatus::Paused, 'Subscription not paused');
            
            // Resume the underlying stream
            let stream_manager = IStreamManagerDispatcher { contract_address: self.stream_manager.read() };
            stream_manager.resume_stream(subscription.stream_id);
            
            // Update subscription status
            subscription.status = SubscriptionStatus::Active;
            self.subscriptions.entry(subscription_id).write(subscription);
            
            self.emit(SubscriptionResumed { subscription_id, subscriber: subscription.subscriber });
            
            true
        }

        fn renew_subscription(ref self: ContractState, subscription_id: u256, duration: u64) -> bool {
            self._assert_not_paused();
            
            let caller = get_caller_address();
            let mut subscription = self.subscriptions.entry(subscription_id).read();
            let plan = self.plans.entry(subscription.plan_id).read();
            
            // Validate subscription exists and caller has permission
            assert(subscription.subscriber == caller, 'Unauthorized');
            assert(duration > 0, 'Duration must be greater than 0');
            
            let current_time = get_block_timestamp();
            let additional_time = duration * plan.interval;
            let new_end_time = if subscription.end_time > current_time {
                subscription.end_time + additional_time
            } else {
                current_time + additional_time
            };
            
            let additional_amount = plan.price * duration.into();
            
            // Create new stream for the renewal period
            let stream_manager = IStreamManagerDispatcher { contract_address: self.stream_manager.read() };
            let new_stream_id = stream_manager.create_stream(
                plan.creator,
                additional_amount,
                plan.price / plan.interval.into(),
                additional_time
            );
            
            // Update subscription
            subscription.stream_id = new_stream_id;
            subscription.end_time = new_end_time;
            subscription.status = SubscriptionStatus::Active;
            self.subscriptions.entry(subscription_id).write(subscription);
            
            // Update analytics
            let current_revenue = self.plan_total_revenue.entry(subscription.plan_id).read();
            self.plan_total_revenue.entry(subscription.plan_id).write(current_revenue + additional_amount);
            
            let global_revenue = self.global_total_revenue.read();
            self.global_total_revenue.write(global_revenue + additional_amount);
            
            // Track manual renewal
            let manual_renewals = self.plan_manual_renewals.entry(subscription.plan_id).read();
            self.plan_manual_renewals.entry(subscription.plan_id).write(manual_renewals + 1);
            
            let total_renewals = self.plan_total_renewals.entry(subscription.plan_id).read();
            self.plan_total_renewals.entry(subscription.plan_id).write(total_renewals + 1);
            
            self.emit(SubscriptionRenewed { subscription_id, subscriber: subscription.subscriber, new_end_time });
            
            true
        }

        fn get_subscription(self: @ContractState, subscription_id: u256) -> Subscription {
            self.subscriptions.entry(subscription_id).read()
        }

        fn get_subscription_status(self: @ContractState, subscription_id: u256) -> SubscriptionStatus {
            let subscription = self.subscriptions.entry(subscription_id).read();
            let current_time = get_block_timestamp();
            
            // Check if subscription has expired
            if subscription.end_time <= current_time && subscription.status == SubscriptionStatus::Active {
                SubscriptionStatus::Expired
            } else {
                subscription.status
            }
        }

        fn get_user_subscriptions(self: @ContractState, user: ContractAddress) -> Array<u256> {
            let mut subscriptions = ArrayTrait::new();
            let count = self.user_subscription_count.read(user);
            
            let mut i = 0;
            while i < count {
                let subscription_id = self.user_subscriptions.read((user, i));
                subscriptions.append(subscription_id);
                i += 1;
            }
            
            subscriptions
        }

        fn get_plan_subscriptions(self: @ContractState, plan_id: u256) -> Array<u256> {
            let mut subscriptions = ArrayTrait::new();
            let count = self.plan_subscription_count.read(plan_id);
            
            let mut i = 0;
            while i < count {
                let subscription_id = self.plan_subscriptions.read((plan_id, i));
                subscriptions.append(subscription_id);
                i += 1;
            }
            
            subscriptions
        }

        fn get_subscription_plan(
            self: @ContractState,
            plan_id: u256
        ) -> (u256, u64, u32, u32) {
            let plan = self.plans.entry(plan_id).read();
            (plan.price, plan.interval, plan.max_subscribers, plan.current_subscribers)
        }

        fn update_subscription_plan(
            ref self: ContractState,
            plan_id: u256,
            new_price: u256,
            new_max_subscribers: u32
        ) -> bool {
            self._assert_not_paused();
            
            let caller = get_caller_address();
            let mut plan = self.plans.entry(plan_id).read();
            
            // Validate caller is plan creator
            assert(plan.creator == caller, 'Unauthorized');
            assert(new_max_subscribers >= plan.current_subscribers, 'Cannot reduce below current');
            
            // Validate new parameters
            validate_subscription_parameters(new_price, plan.interval, new_max_subscribers).unwrap();
            
            plan.price = new_price;
            plan.max_subscribers = new_max_subscribers;
            self.plans.entry(plan_id).write(plan);
            
            self.emit(PlanUpdated { plan_id, new_price, new_max_subscribers });
            
            true
        }

        fn process_auto_renewals(ref self: ContractState, max_renewals: u32) -> u32 {
            self._assert_not_paused();
            
            let current_time = get_block_timestamp();
            let mut renewed_count = 0_u32;
            let mut processed = 0_u32;
            
            // This is a simplified implementation - in practice, you'd want to maintain
            // a more efficient data structure for tracking expiring subscriptions
            let mut subscription_id = 1_u256;
            let max_subscription_id = self.next_subscription_id.read();
            
            while subscription_id < max_subscription_id && processed < max_renewals {
                let mut subscription = self.subscriptions.entry(subscription_id).read();
                
                if subscription.auto_renew 
                    && subscription.status == SubscriptionStatus::Active
                    && subscription.end_time <= current_time {
                    
                    let plan = self.plans.entry(subscription.plan_id).read();
                    
                    // Try to renew for one more period
                    let renewal_amount = plan.price;
                    let stream_manager = IStreamManagerDispatcher { contract_address: self.stream_manager.read() };
                    
                    // Create new stream for renewal
                    let new_stream_id = stream_manager.create_stream(
                        plan.creator,
                        renewal_amount,
                        plan.price / plan.interval.into(),
                        plan.interval
                    );
                    
                    // Update subscription
                    subscription.stream_id = new_stream_id;
                    subscription.end_time = current_time + plan.interval;
                    self.subscriptions.entry(subscription_id).write(subscription);
                    
                    // Update analytics
                    let current_revenue = self.plan_total_revenue.entry(subscription.plan_id).read();
                    self.plan_total_revenue.entry(subscription.plan_id).write(current_revenue + renewal_amount);
                    
                    let global_revenue = self.global_total_revenue.read();
                    self.global_total_revenue.write(global_revenue + renewal_amount);
                    
                    // Track auto renewal
                    let auto_renewals = self.plan_auto_renewals.entry(subscription.plan_id).read();
                    self.plan_auto_renewals.entry(subscription.plan_id).write(auto_renewals + 1);
                    
                    let total_renewals = self.plan_total_renewals.entry(subscription.plan_id).read();
                    self.plan_total_renewals.entry(subscription.plan_id).write(total_renewals + 1);
                    
                    renewed_count += 1;
                    
                    self.emit(SubscriptionRenewed { 
                        subscription_id, 
                        subscriber: subscription.subscriber, 
                        new_end_time: subscription.end_time 
                    });
                }
                
                subscription_id += 1;
                processed += 1;
            }
            
            renewed_count
        }

        fn get_plan_analytics(
            self: @ContractState,
            plan_id: u256
        ) -> (u256, u32, u32) {
            let plan = self.plans.entry(plan_id).read();
            let total_revenue = self.plan_total_revenue.entry(plan_id).read();
            let total_subscribers = self.plan_total_subscribers.entry(plan_id).read();
            
            (total_revenue, plan.current_subscribers, total_subscribers)
        }

        fn get_plan_status_breakdown(
            self: @ContractState,
            plan_id: u256
        ) -> (u32, u32, u32, u32) {
            let mut active_count = 0_u32;
            let mut paused_count = 0_u32;
            let mut cancelled_count = 0_u32;
            let mut expired_count = 0_u32;
            
            let subscription_count = self.plan_subscription_count.read(plan_id);
            let current_time = get_block_timestamp();
            
            let mut i = 0;
            while i < subscription_count {
                let subscription_id = self.plan_subscriptions.read((plan_id, i));
                let subscription = self.subscriptions.entry(subscription_id).read();
                
                match subscription.status {
                    SubscriptionStatus::Active => {
                        if subscription.end_time <= current_time {
                            expired_count += 1;
                        } else {
                            active_count += 1;
                        }
                    },
                    SubscriptionStatus::Paused => paused_count += 1,
                    SubscriptionStatus::Cancelled => cancelled_count += 1,
                    SubscriptionStatus::Expired => expired_count += 1,
                }
                
                i += 1;
            }
            
            (active_count, paused_count, cancelled_count, expired_count)
        }

        fn get_plan_renewal_stats(
            self: @ContractState,
            plan_id: u256
        ) -> (u32, u32, u32) {
            let total_renewals = self.plan_total_renewals.entry(plan_id).read();
            let auto_renewals = self.plan_auto_renewals.entry(plan_id).read();
            let manual_renewals = self.plan_manual_renewals.entry(plan_id).read();
            
            (total_renewals, auto_renewals, manual_renewals)
        }

        fn get_platform_analytics(
            self: @ContractState
        ) -> (u256, u256, u256, u32) {
            let total_plans = self.total_plans_created.read();
            let total_subscriptions = self.total_subscriptions_created.read();
            let total_revenue = self.global_total_revenue.read();
            
            // Count active subscriptions across all plans
            let mut active_subscriptions = 0_u32;
            let mut plan_id = 1_u256;
            let max_plan_id = self.next_plan_id.read();
            
            while plan_id < max_plan_id {
                let plan = self.plans.entry(plan_id).read();
                active_subscriptions += plan.current_subscribers;
                plan_id += 1;
            }
            
            (total_plans, total_subscriptions, total_revenue, active_subscriptions)
        }

        fn get_plan_churn_rate(self: @ContractState, plan_id: u256) -> u32 {
            let total_subscribers = self.plan_total_subscribers.entry(plan_id).read();
            let cancelled_count = self.plan_cancelled_count.entry(plan_id).read();
            
            if total_subscribers == 0 {
                return 0;
            }
            
            // Return churn rate as percentage scaled by 10000 (e.g., 2500 = 25.00%)
            (cancelled_count.into() * 10000) / total_subscribers.into()
        }

        fn get_plan_avg_duration(self: @ContractState, plan_id: u256) -> u64 {
            let total_subscribers = self.plan_total_subscribers.entry(plan_id).read();
            let total_duration = self.plan_total_duration.entry(plan_id).read();
            
            if total_subscribers == 0 {
                return 0;
            }
            
            total_duration / total_subscribers.into()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_not_paused(self: @ContractState) {
            assert(!self.paused.read(), 'Contract is paused');
        }

        fn _add_user_subscription(ref self: ContractState, user: ContractAddress, subscription_id: u256) {
            let count = self.user_subscription_count.read(user);
            self.user_subscriptions.write((user, count), subscription_id);
            self.user_subscription_count.write(user, count + 1);
        }

        fn _add_plan_subscription(ref self: ContractState, plan_id: u256, subscription_id: u256) {
            let count = self.plan_subscription_count.read(plan_id);
            self.plan_subscriptions.write((plan_id, count), subscription_id);
            self.plan_subscription_count.write(plan_id, count + 1);
        }
    }
}