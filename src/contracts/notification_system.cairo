use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use crate::types::{BitFlowError, ErrorSeverity};

#[starknet::interface]
pub trait INotificationSystem<TContractState> {
    // Notification management
    fn send_notification(ref self: TContractState, recipient: ContractAddress, notification: Notification) -> u256;
    fn get_notifications(self: @TContractState, recipient: ContractAddress) -> Array<Notification>;
    fn mark_notification_read(ref self: TContractState, notification_id: u256) -> bool;
    fn get_unread_count(self: @TContractState, recipient: ContractAddress) -> u256;
    
    // Subscription management
    fn subscribe_to_alerts(ref self: TContractState, alert_types: Array<NotificationType>) -> bool;
    fn unsubscribe_from_alerts(ref self: TContractState, alert_types: Array<NotificationType>) -> bool;
    fn get_subscriptions(self: @TContractState, user: ContractAddress) -> Array<NotificationType>;
    
    // Notification channels
    fn add_notification_channel(ref self: TContractState, channel: NotificationChannel) -> bool;
    fn remove_notification_channel(ref self: TContractState, channel_id: u256) -> bool;
    fn get_notification_channels(self: @TContractState, user: ContractAddress) -> Array<NotificationChannel>;
    
    // Batch operations
    fn send_batch_notifications(ref self: TContractState, notifications: Array<BatchNotification>) -> Array<u256>;
    fn mark_all_read(ref self: TContractState, recipient: ContractAddress) -> bool;
    
    // Configuration
    fn set_notification_preferences(ref self: TContractState, preferences: NotificationPreferences) -> bool;
    fn get_notification_preferences(self: @TContractState, user: ContractAddress) -> NotificationPreferences;
}

#[derive(Drop, Serde, starknet::Store)]
pub enum NotificationType {
    SystemAlert,
    ErrorReport,
    StreamUpdate,
    BridgeStatus,
    YieldUpdate,
    SecurityAlert,
    MaintenanceNotice,
    RecoveryComplete,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum NotificationPriority {
    Low,
    Normal,
    High,
    Critical,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Notification {
    pub id: u256,
    pub recipient: ContractAddress,
    pub notification_type: NotificationType,
    pub priority: NotificationPriority,
    pub title: felt252,
    pub message: felt252,
    pub timestamp: u64,
    pub read: bool,
    pub expires_at: u64,
    pub action_required: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum ChannelType {
    InApp,
    Email,
    SMS,
    Webhook,
    Push,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct NotificationChannel {
    pub id: u256,
    pub user: ContractAddress,
    pub channel_type: ChannelType,
    pub endpoint: felt252, // Email, phone, webhook URL, etc.
    pub enabled: bool,
    pub verified: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct BatchNotification {
    pub recipient: ContractAddress,
    pub notification: Notification,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct NotificationPreferences {
    pub user: ContractAddress,
    pub enabled_types: Array<NotificationType>,
    pub quiet_hours_start: u64,
    pub quiet_hours_end: u64,
    pub max_notifications_per_hour: u32,
    pub consolidate_similar: bool,
}

#[starknet::contract]
pub mod NotificationSystem {
    use super::*;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };

    #[storage]
    struct Storage {
        // Notifications
        notifications: Map<u256, Notification>,
        next_notification_id: u256,
        user_notifications: Map<(ContractAddress, u256), u256>, // (user, index) -> notification_id
        user_notification_count: Map<ContractAddress, u256>,
        unread_counts: Map<ContractAddress, u256>,
        
        // Subscriptions
        user_subscriptions: Map<(ContractAddress, NotificationType), bool>,
        
        // Channels
        notification_channels: Map<u256, NotificationChannel>,
        next_channel_id: u256,
        user_channels: Map<(ContractAddress, u256), u256>, // (user, index) -> channel_id
        user_channel_count: Map<ContractAddress, u256>,
        
        // Preferences
        user_preferences: Map<ContractAddress, NotificationPreferences>,
        
        // Rate limiting
        hourly_notification_counts: Map<(ContractAddress, u64), u32>, // (user, hour) -> count
        
        // Configuration
        owner: ContractAddress,
        system_enabled: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        NotificationSent: NotificationSent,
        NotificationRead: NotificationRead,
        SubscriptionUpdated: SubscriptionUpdated,
        ChannelAdded: ChannelAdded,
        ChannelRemoved: ChannelRemoved,
        PreferencesUpdated: PreferencesUpdated,
        BatchNotificationsSent: BatchNotificationsSent,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NotificationSent {
        pub notification_id: u256,
        pub recipient: ContractAddress,
        pub notification_type: NotificationType,
        pub priority: NotificationPriority,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NotificationRead {
        pub notification_id: u256,
        pub recipient: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SubscriptionUpdated {
        pub user: ContractAddress,
        pub notification_type: NotificationType,
        pub subscribed: bool,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ChannelAdded {
        pub channel_id: u256,
        pub user: ContractAddress,
        pub channel_type: ChannelType,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ChannelRemoved {
        pub channel_id: u256,
        pub user: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PreferencesUpdated {
        pub user: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BatchNotificationsSent {
        pub count: u256,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.next_notification_id.write(1);
        self.next_channel_id.write(1);
        self.system_enabled.write(true);
    }

    #[abi(embed_v0)]
    impl NotificationSystemImpl of INotificationSystem<ContractState> {
        fn send_notification(
            ref self: ContractState,
            recipient: ContractAddress,
            notification: Notification
        ) -> u256 {
            assert(self.system_enabled.read(), 'Notification system disabled');
            
            // Check if user is subscribed to this notification type
            if !self.user_subscriptions.entry((recipient, notification.notification_type)).read() {
                return 0; // User not subscribed
            }
            
            // Check rate limiting
            if !self._check_rate_limit(recipient) {
                return 0; // Rate limit exceeded
            }
            
            // Check quiet hours
            if self._is_quiet_hours(recipient) && !matches!(notification.priority, NotificationPriority::Critical) {
                return 0; // In quiet hours, only critical notifications
            }
            
            let notification_id = self.next_notification_id.read();
            let mut final_notification = notification;
            final_notification.id = notification_id;
            final_notification.timestamp = get_block_timestamp();
            
            // Store notification
            self.notifications.entry(notification_id).write(final_notification);
            self.next_notification_id.write(notification_id + 1);
            
            // Add to user's notification list
            let user_count = self.user_notification_count.entry(recipient).read();
            self.user_notifications.entry((recipient, user_count)).write(notification_id);
            self.user_notification_count.entry(recipient).write(user_count + 1);
            
            // Update unread count
            let unread_count = self.unread_counts.entry(recipient).read();
            self.unread_counts.entry(recipient).write(unread_count + 1);
            
            // Update rate limiting counter
            self._increment_hourly_count(recipient);
            
            // Emit event
            self.emit(NotificationSent {
                notification_id,
                recipient,
                notification_type: final_notification.notification_type,
                priority: final_notification.priority,
                timestamp: final_notification.timestamp,
            });
            
            notification_id
        }

        fn get_notifications(self: @ContractState, recipient: ContractAddress) -> Array<Notification> {
            let mut notifications = ArrayTrait::new();
            let count = self.user_notification_count.entry(recipient).read();
            
            let mut i = 0;
            while i < count {
                let notification_id = self.user_notifications.entry((recipient, i)).read();
                let notification = self.notifications.entry(notification_id).read();
                if notification.id != 0 {
                    notifications.append(notification);
                }
                i += 1;
            };
            
            notifications
        }

        fn mark_notification_read(ref self: ContractState, notification_id: u256) -> bool {
            let mut notification = self.notifications.entry(notification_id).read();
            if notification.id == 0 || notification.read {
                return false;
            }
            
            // Verify caller is the recipient
            let caller = get_caller_address();
            if caller != notification.recipient {
                return false;
            }
            
            notification.read = true;
            self.notifications.entry(notification_id).write(notification);
            
            // Update unread count
            let unread_count = self.unread_counts.entry(notification.recipient).read();
            if unread_count > 0 {
                self.unread_counts.entry(notification.recipient).write(unread_count - 1);
            }
            
            self.emit(NotificationRead {
                notification_id,
                recipient: notification.recipient,
                timestamp: get_block_timestamp(),
            });
            
            true
        }

        fn get_unread_count(self: @ContractState, recipient: ContractAddress) -> u256 {
            self.unread_counts.entry(recipient).read()
        }

        fn subscribe_to_alerts(ref self: ContractState, alert_types: Array<NotificationType>) -> bool {
            let caller = get_caller_address();
            
            let mut i = 0;
            while i < alert_types.len() {
                let alert_type = *alert_types.at(i);
                self.user_subscriptions.entry((caller, alert_type)).write(true);
                
                self.emit(SubscriptionUpdated {
                    user: caller,
                    notification_type: alert_type,
                    subscribed: true,
                    timestamp: get_block_timestamp(),
                });
                
                i += 1;
            };
            
            true
        }

        fn unsubscribe_from_alerts(ref self: ContractState, alert_types: Array<NotificationType>) -> bool {
            let caller = get_caller_address();
            
            let mut i = 0;
            while i < alert_types.len() {
                let alert_type = *alert_types.at(i);
                self.user_subscriptions.entry((caller, alert_type)).write(false);
                
                self.emit(SubscriptionUpdated {
                    user: caller,
                    notification_type: alert_type,
                    subscribed: false,
                    timestamp: get_block_timestamp(),
                });
                
                i += 1;
            };
            
            true
        }

        fn get_subscriptions(self: @ContractState, user: ContractAddress) -> Array<NotificationType> {
            let mut subscriptions = ArrayTrait::new();
            
            // Check all notification types (this is a simplified approach)
            let notification_types = self._get_all_notification_types();
            let mut i = 0;
            while i < notification_types.len() {
                let notification_type = *notification_types.at(i);
                if self.user_subscriptions.entry((user, notification_type)).read() {
                    subscriptions.append(notification_type);
                }
                i += 1;
            };
            
            subscriptions
        }

        fn add_notification_channel(ref self: ContractState, channel: NotificationChannel) -> bool {
            let caller = get_caller_address();
            let channel_id = self.next_channel_id.read();
            
            let mut final_channel = channel;
            final_channel.id = channel_id;
            final_channel.user = caller;
            
            self.notification_channels.entry(channel_id).write(final_channel);
            self.next_channel_id.write(channel_id + 1);
            
            // Add to user's channel list
            let user_count = self.user_channel_count.entry(caller).read();
            self.user_channels.entry((caller, user_count)).write(channel_id);
            self.user_channel_count.entry(caller).write(user_count + 1);
            
            self.emit(ChannelAdded {
                channel_id,
                user: caller,
                channel_type: final_channel.channel_type,
                timestamp: get_block_timestamp(),
            });
            
            true
        }

        fn remove_notification_channel(ref self: ContractState, channel_id: u256) -> bool {
            let caller = get_caller_address();
            let channel = self.notification_channels.entry(channel_id).read();
            
            if channel.id == 0 || channel.user != caller {
                return false;
            }
            
            // Mark channel as disabled (we can't actually delete from storage)
            let mut updated_channel = channel;
            updated_channel.enabled = false;
            self.notification_channels.entry(channel_id).write(updated_channel);
            
            self.emit(ChannelRemoved {
                channel_id,
                user: caller,
                timestamp: get_block_timestamp(),
            });
            
            true
        }

        fn get_notification_channels(self: @ContractState, user: ContractAddress) -> Array<NotificationChannel> {
            let mut channels = ArrayTrait::new();
            let count = self.user_channel_count.entry(user).read();
            
            let mut i = 0;
            while i < count {
                let channel_id = self.user_channels.entry((user, i)).read();
                let channel = self.notification_channels.entry(channel_id).read();
                if channel.id != 0 && channel.enabled {
                    channels.append(channel);
                }
                i += 1;
            };
            
            channels
        }

        fn send_batch_notifications(
            ref self: ContractState,
            notifications: Array<BatchNotification>
        ) -> Array<u256> {
            let mut notification_ids = ArrayTrait::new();
            
            let mut i = 0;
            while i < notifications.len() {
                let batch_notification = *notifications.at(i);
                let notification_id = self.send_notification(
                    batch_notification.recipient,
                    batch_notification.notification
                );
                notification_ids.append(notification_id);
                i += 1;
            };
            
            self.emit(BatchNotificationsSent {
                count: notifications.len().into(),
                timestamp: get_block_timestamp(),
            });
            
            notification_ids
        }

        fn mark_all_read(ref self: ContractState, recipient: ContractAddress) -> bool {
            let caller = get_caller_address();
            if caller != recipient {
                return false;
            }
            
            let count = self.user_notification_count.entry(recipient).read();
            
            let mut i = 0;
            while i < count {
                let notification_id = self.user_notifications.entry((recipient, i)).read();
                let mut notification = self.notifications.entry(notification_id).read();
                if notification.id != 0 && !notification.read {
                    notification.read = true;
                    self.notifications.entry(notification_id).write(notification);
                }
                i += 1;
            };
            
            // Reset unread count
            self.unread_counts.entry(recipient).write(0);
            
            true
        }

        fn set_notification_preferences(
            ref self: ContractState,
            preferences: NotificationPreferences
        ) -> bool {
            let caller = get_caller_address();
            let mut final_preferences = preferences;
            final_preferences.user = caller;
            
            self.user_preferences.entry(caller).write(final_preferences);
            
            self.emit(PreferencesUpdated {
                user: caller,
                timestamp: get_block_timestamp(),
            });
            
            true
        }

        fn get_notification_preferences(
            self: @ContractState,
            user: ContractAddress
        ) -> NotificationPreferences {
            self.user_preferences.entry(user).read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _check_rate_limit(self: @ContractState, user: ContractAddress) -> bool {
            let preferences = self.user_preferences.entry(user).read();
            if preferences.max_notifications_per_hour == 0 {
                return true; // No rate limit set
            }
            
            let current_hour = get_block_timestamp() / 3600;
            let current_count = self.hourly_notification_counts.entry((user, current_hour)).read();
            
            current_count < preferences.max_notifications_per_hour
        }

        fn _is_quiet_hours(self: @ContractState, user: ContractAddress) -> bool {
            let preferences = self.user_preferences.entry(user).read();
            if preferences.quiet_hours_start == 0 && preferences.quiet_hours_end == 0 {
                return false; // No quiet hours set
            }
            
            let current_time = get_block_timestamp() % 86400; // Seconds in day
            let start = preferences.quiet_hours_start;
            let end = preferences.quiet_hours_end;
            
            if start < end {
                current_time >= start && current_time <= end
            } else {
                // Quiet hours span midnight
                current_time >= start || current_time <= end
            }
        }

        fn _increment_hourly_count(ref self: ContractState, user: ContractAddress) {
            let current_hour = get_block_timestamp() / 3600;
            let current_count = self.hourly_notification_counts.entry((user, current_hour)).read();
            self.hourly_notification_counts.entry((user, current_hour)).write(current_count + 1);
        }

        fn _get_all_notification_types(self: @ContractState) -> Array<NotificationType> {
            let mut types = ArrayTrait::new();
            types.append(NotificationType::SystemAlert);
            types.append(NotificationType::ErrorReport);
            types.append(NotificationType::StreamUpdate);
            types.append(NotificationType::BridgeStatus);
            types.append(NotificationType::YieldUpdate);
            types.append(NotificationType::SecurityAlert);
            types.append(NotificationType::MaintenanceNotice);
            types.append(NotificationType::RecoveryComplete);
            types
        }
    }
}