use starknet::{ContractAddress, contract_address_const};
use starknet::testing::{set_caller_address, set_block_timestamp};

use bitflow::contracts::notification_system::{
    NotificationSystem, INotificationSystemDispatcher, INotificationSystemDispatcherTrait,
    Notification, NotificationType, NotificationPriority, NotificationChannel, ChannelType,
    NotificationPreferences, BatchNotification
};

fn deploy_notification_system() -> INotificationSystemDispatcher {
    let owner = contract_address_const::<'owner'>();
    let contract = NotificationSystem::deploy(owner).unwrap();
    INotificationSystemDispatcher { contract_address: contract }
}

fn create_test_notification(recipient: ContractAddress) -> Notification {
    Notification {
        id: 0, // Will be set by the system
        recipient,
        notification_type: NotificationType::SystemAlert,
        priority: NotificationPriority::Normal,
        title: 'Test Alert',
        message: 'This is a test notification',
        timestamp: 0, // Will be set by the system
        read: false,
        expires_at: 0,
        action_required: false,
    }
}

#[test]
fn test_notification_system_deployment() {
    let notification_system = deploy_notification_system();
    let user = contract_address_const::<'user'>();
    
    // Check initial state
    let notifications = notification_system.get_notifications(user);
    assert(notifications.len() == 0, 'Should have no notifications initially');
    
    let unread_count = notification_system.get_unread_count(user);
    assert(unread_count == 0, 'Should have no unread notifications initially');
}

#[test]
fn test_send_notification() {
    let notification_system = deploy_notification_system();
    let user = contract_address_const::<'user'>();
    let sender = contract_address_const::<'sender'>();
    
    set_caller_address(sender);
    set_block_timestamp(1000);
    
    // First subscribe to the notification type
    set_caller_address(user);
    let mut alert_types = ArrayTrait::new();
    alert_types.append(NotificationType::SystemAlert);
    notification_system.subscribe_to_alerts(alert_types);
    
    // Send notification
    set_caller_address(sender);
    let notification = create_test_notification(user);
    let notification_id = notification_system.send_notification(user, notification);
    
    assert(notification_id > 0, 'Notification ID should be positive');
    
    // Check user's notifications
    let notifications = notification_system.get_notifications(user);
    assert(notifications.len() == 1, 'User should have one notification');
    
    let received_notification = notifications.at(0);
    assert(received_notification.recipient == user, 'Wrong recipient');
    assert(received_notification.title == 'Test Alert', 'Wrong title');
    assert(received_notification.timestamp == 1000, 'Wrong timestamp');
    
    // Check unread count
    let unread_count = notification_system.get_unread_count(user);
    assert(unread_count == 1, 'Should have one unread notification');
}

#[test]
fn test_notification_without_subscription() {
    let notification_system = deploy_notification_system();
    let user = contract_address_const::<'user'>();
    let sender = contract_address_const::<'sender'>();
    
    set_caller_address(sender);
    
    // Send notification without user being subscribed
    let notification = create_test_notification(user);
    let notification_id = notification_system.send_notification(user, notification);
    
    assert(notification_id == 0, 'Should not send to unsubscribed user');
    
    // Check user has no notifications
    let notifications = notification_system.get_notifications(user);
    assert(notifications.len() == 0, 'User should have no notifications');
}

#[test]
fn test_mark_notification_read() {
    let notification_system = deploy_notification_system();
    let user = contract_address_const::<'user'>();
    let sender = contract_address_const::<'sender'>();
    
    // Subscribe and send notification
    set_caller_address(user);
    let mut alert_types = ArrayTrait::new();
    alert_types.append(NotificationType::SystemAlert);
    notification_system.subscribe_to_alerts(alert_types);
    
    set_caller_address(sender);
    let notification = create_test_notification(user);
    let notification_id = notification_system.send_notification(user, notification);
    
    // Mark as read
    set_caller_address(user);
    let success = notification_system.mark_notification_read(notification_id);
    assert(success, 'Marking as read should succeed');
    
    // Check unread count decreased
    let unread_count = notification_system.get_unread_count(user);
    assert(unread_count == 0, 'Should have no unread notifications');
    
    // Check notification is marked as read
    let notifications = notification_system.get_notifications(user);
    let notification = notifications.at(0);
    assert(notification.read, 'Notification should be marked as read');
}

#[test]
fn test_mark_notification_read_unauthorized() {
    let notification_system = deploy_notification_system();
    let user = contract_address_const::<'user'>();
    let other_user = contract_address_const::<'other_user'>();
    let sender = contract_address_const::<'sender'>();
    
    // Subscribe and send notification
    set_caller_address(user);
    let mut alert_types = ArrayTrait::new();
    alert_types.append(NotificationType::SystemAlert);
    notification_system.subscribe_to_alerts(alert_types);
    
    set_caller_address(sender);
    let notification = create_test_notification(user);
    let notification_id = notification_system.send_notification(user, notification);
    
    // Try to mark as read from different user
    set_caller_address(other_user);
    let success = notification_system.mark_notification_read(notification_id);
    assert(!success, 'Should not allow unauthorized read marking');
}

#[test]
fn test_subscription_management() {
    let notification_system = deploy_notification_system();
    let user = contract_address_const::<'user'>();
    
    set_caller_address(user);
    
    // Subscribe to multiple alert types
    let mut alert_types = ArrayTrait::new();
    alert_types.append(NotificationType::SystemAlert);
    alert_types.append(NotificationType::ErrorReport);
    alert_types.append(NotificationType::StreamUpdate);
    
    let success = notification_system.subscribe_to_alerts(alert_types);
    assert(success, 'Subscription should succeed');
    
    // Check subscriptions
    let subscriptions = notification_system.get_subscriptions(user);
    assert(subscriptions.len() == 3, 'Should have 3 subscriptions');
    
    // Unsubscribe from some alerts
    let mut unsubscribe_types = ArrayTrait::new();
    unsubscribe_types.append(NotificationType::StreamUpdate);
    
    let success = notification_system.unsubscribe_from_alerts(unsubscribe_types);
    assert(success, 'Unsubscription should succeed');
    
    // Check updated subscriptions
    let updated_subscriptions = notification_system.get_subscriptions(user);
    assert(updated_subscriptions.len() == 2, 'Should have 2 subscriptions after unsubscribe');
}

#[test]
fn test_notification_channels() {
    let notification_system = deploy_notification_system();
    let user = contract_address_const::<'user'>();
    
    set_caller_address(user);
    
    // Add notification channels
    let email_channel = NotificationChannel {
        id: 0, // Will be set by system
        user,
        channel_type: ChannelType::Email,
        endpoint: 'user@example.com',
        enabled: true,
        verified: false,
    };
    
    let webhook_channel = NotificationChannel {
        id: 0, // Will be set by system
        user,
        channel_type: ChannelType::Webhook,
        endpoint: 'https://api.example.com/webhook',
        enabled: true,
        verified: true,
    };
    
    let success1 = notification_system.add_notification_channel(email_channel);
    let success2 = notification_system.add_notification_channel(webhook_channel);
    
    assert(success1, 'Adding email channel should succeed');
    assert(success2, 'Adding webhook channel should succeed');
    
    // Get user's channels
    let channels = notification_system.get_notification_channels(user);
    assert(channels.len() == 2, 'User should have 2 channels');
    
    // Remove a channel
    let first_channel = channels.at(0);
    let success = notification_system.remove_notification_channel(first_channel.id);
    assert(success, 'Removing channel should succeed');
    
    // Check updated channels
    let updated_channels = notification_system.get_notification_channels(user);
    assert(updated_channels.len() == 1, 'User should have 1 channel after removal');
}

#[test]
fn test_batch_notifications() {
    let notification_system = deploy_notification_system();
    let user1 = contract_address_const::<'user1'>();
    let user2 = contract_address_const::<'user2'>();
    let sender = contract_address_const::<'sender'>();
    
    // Subscribe both users
    set_caller_address(user1);
    let mut alert_types = ArrayTrait::new();
    alert_types.append(NotificationType::SystemAlert);
    notification_system.subscribe_to_alerts(alert_types);
    
    set_caller_address(user2);
    let mut alert_types = ArrayTrait::new();
    alert_types.append(NotificationType::SystemAlert);
    notification_system.subscribe_to_alerts(alert_types);
    
    // Send batch notifications
    set_caller_address(sender);
    let mut batch_notifications = ArrayTrait::new();
    
    let notification1 = BatchNotification {
        recipient: user1,
        notification: create_test_notification(user1),
    };
    
    let notification2 = BatchNotification {
        recipient: user2,
        notification: create_test_notification(user2),
    };
    
    batch_notifications.append(notification1);
    batch_notifications.append(notification2);
    
    let notification_ids = notification_system.send_batch_notifications(batch_notifications);
    assert(notification_ids.len() == 2, 'Should return 2 notification IDs');
    
    // Check both users received notifications
    let user1_notifications = notification_system.get_notifications(user1);
    let user2_notifications = notification_system.get_notifications(user2);
    
    assert(user1_notifications.len() == 1, 'User1 should have 1 notification');
    assert(user2_notifications.len() == 1, 'User2 should have 1 notification');
}

#[test]
fn test_mark_all_read() {
    let notification_system = deploy_notification_system();
    let user = contract_address_const::<'user'>();
    let sender = contract_address_const::<'sender'>();
    
    // Subscribe and send multiple notifications
    set_caller_address(user);
    let mut alert_types = ArrayTrait::new();
    alert_types.append(NotificationType::SystemAlert);
    alert_types.append(NotificationType::ErrorReport);
    notification_system.subscribe_to_alerts(alert_types);
    
    set_caller_address(sender);
    
    // Send multiple notifications
    let notification1 = create_test_notification(user);
    let mut notification2 = create_test_notification(user);
    notification2.notification_type = NotificationType::ErrorReport;
    notification2.title = 'Error Alert';
    
    notification_system.send_notification(user, notification1);
    notification_system.send_notification(user, notification2);
    
    // Check unread count
    let unread_count = notification_system.get_unread_count(user);
    assert(unread_count == 2, 'Should have 2 unread notifications');
    
    // Mark all as read
    set_caller_address(user);
    let success = notification_system.mark_all_read(user);
    assert(success, 'Mark all read should succeed');
    
    // Check unread count is now 0
    let unread_count_after = notification_system.get_unread_count(user);
    assert(unread_count_after == 0, 'Should have no unread notifications');
}

#[test]
fn test_notification_preferences() {
    let notification_system = deploy_notification_system();
    let user = contract_address_const::<'user'>();
    
    set_caller_address(user);
    
    // Set notification preferences
    let mut enabled_types = ArrayTrait::new();
    enabled_types.append(NotificationType::SystemAlert);
    enabled_types.append(NotificationType::SecurityAlert);
    
    let preferences = NotificationPreferences {
        user,
        enabled_types,
        quiet_hours_start: 22 * 3600, // 10 PM
        quiet_hours_end: 8 * 3600,    // 8 AM
        max_notifications_per_hour: 10,
        consolidate_similar: true,
    };
    
    let success = notification_system.set_notification_preferences(preferences);
    assert(success, 'Setting preferences should succeed');
    
    // Get preferences
    let retrieved_preferences = notification_system.get_notification_preferences(user);
    assert(retrieved_preferences.user == user, 'Wrong user in preferences');
    assert(retrieved_preferences.max_notifications_per_hour == 10, 'Wrong max notifications');
    assert(retrieved_preferences.consolidate_similar, 'Wrong consolidate setting');
}

#[test]
fn test_critical_notification_during_quiet_hours() {
    let notification_system = deploy_notification_system();
    let user = contract_address_const::<'user'>();
    let sender = contract_address_const::<'sender'>();
    
    set_caller_address(user);
    
    // Set quiet hours and subscribe
    let mut enabled_types = ArrayTrait::new();
    enabled_types.append(NotificationType::SecurityAlert);
    
    let preferences = NotificationPreferences {
        user,
        enabled_types,
        quiet_hours_start: 0,    // Start of day
        quiet_hours_end: 86400,  // End of day (always quiet)
        max_notifications_per_hour: 10,
        consolidate_similar: false,
    };
    
    notification_system.set_notification_preferences(preferences);
    notification_system.subscribe_to_alerts(enabled_types);
    
    // Send critical notification during quiet hours
    set_caller_address(sender);
    set_block_timestamp(12 * 3600); // Noon (during quiet hours)
    
    let mut critical_notification = create_test_notification(user);
    critical_notification.notification_type = NotificationType::SecurityAlert;
    critical_notification.priority = NotificationPriority::Critical;
    critical_notification.title = 'Critical Security Alert';
    
    let notification_id = notification_system.send_notification(user, critical_notification);
    assert(notification_id > 0, 'Critical notification should be sent during quiet hours');
    
    // Send normal notification during quiet hours
    let mut normal_notification = create_test_notification(user);
    normal_notification.notification_type = NotificationType::SecurityAlert;
    normal_notification.priority = NotificationPriority::Normal;
    
    let notification_id2 = notification_system.send_notification(user, normal_notification);
    assert(notification_id2 == 0, 'Normal notification should not be sent during quiet hours');
}

#[test]
fn test_notification_rate_limiting() {
    let notification_system = deploy_notification_system();
    let user = contract_address_const::<'user'>();
    let sender = contract_address_const::<'sender'>();
    
    set_caller_address(user);
    
    // Set rate limit and subscribe
    let mut enabled_types = ArrayTrait::new();
    enabled_types.append(NotificationType::SystemAlert);
    
    let preferences = NotificationPreferences {
        user,
        enabled_types,
        quiet_hours_start: 0,
        quiet_hours_end: 0, // No quiet hours
        max_notifications_per_hour: 2, // Very low limit for testing
        consolidate_similar: false,
    };
    
    notification_system.set_notification_preferences(preferences);
    notification_system.subscribe_to_alerts(enabled_types);
    
    set_caller_address(sender);
    set_block_timestamp(3600); // 1 hour timestamp
    
    // Send notifications up to limit
    let notification1 = create_test_notification(user);
    let notification2 = create_test_notification(user);
    let notification3 = create_test_notification(user);
    
    let id1 = notification_system.send_notification(user, notification1);
    let id2 = notification_system.send_notification(user, notification2);
    let id3 = notification_system.send_notification(user, notification3);
    
    assert(id1 > 0, 'First notification should succeed');
    assert(id2 > 0, 'Second notification should succeed');
    assert(id3 == 0, 'Third notification should be rate limited');
    
    // Check user only received 2 notifications
    let notifications = notification_system.get_notifications(user);
    assert(notifications.len() == 2, 'User should have only 2 notifications due to rate limit');
}