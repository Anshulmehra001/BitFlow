use starknet::{ContractAddress, contract_address_const};
use starknet::testing::{set_caller_address, set_block_timestamp};

use bitflow::contracts::system_monitor::{
    SystemMonitor, ISystemMonitorDispatcher, ISystemMonitorDispatcherTrait,
    HealthMetrics, AlertMetric, AlertSeverity, FailureType, FailureRule, ContractType
};
use bitflow::types::SystemHealthStatus;

fn deploy_system_monitor() -> ISystemMonitorDispatcher {
    let owner = contract_address_const::<'owner'>();
    let contract = SystemMonitor::deploy(owner).unwrap();
    ISystemMonitorDispatcher { contract_address: contract }
}

#[test]
fn test_system_monitor_deployment() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Check initial health status
    let health = monitor.check_system_health();
    assert(matches!(health, SystemHealthStatus::Healthy), 'Should be healthy initially');
}

#[test]
fn test_health_metrics() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    set_block_timestamp(1000);
    
    // Get initial metrics
    let metrics = monitor.get_health_metrics();
    assert(metrics.system_uptime == 0, 'Initial uptime should be 0');
    assert(metrics.total_transactions == 0, 'Initial transactions should be 0');
    assert(metrics.failed_transactions == 0, 'Initial failed transactions should be 0');
    
    // Check system health to update metrics
    monitor.check_system_health();
    
    let updated_metrics = monitor.get_health_metrics();
    assert(updated_metrics.last_updated == 1000, 'Metrics should be updated');
}

#[test]
fn test_health_check_interval() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Set custom health check interval
    let success = monitor.set_health_check_interval(600); // 10 minutes
    assert(success, 'Setting interval should succeed');
}

#[test]
#[should_panic(expected: ('Only owner can call',))]
fn test_health_check_interval_unauthorized() {
    let monitor = deploy_system_monitor();
    let unauthorized = contract_address_const::<'unauthorized'>();
    set_caller_address(unauthorized);
    
    // Should fail for non-owner
    monitor.set_health_check_interval(600);
}

#[test]
fn test_contract_monitoring() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    let stream_manager = contract_address_const::<'stream_manager'>();
    let bridge_adapter = contract_address_const::<'bridge_adapter'>();
    let yield_manager = contract_address_const::<'yield_manager'>();
    
    // Add contracts to monitoring
    let success1 = monitor.monitor_stream_manager(stream_manager);
    let success2 = monitor.monitor_bridge_adapter(bridge_adapter);
    let success3 = monitor.monitor_yield_manager(yield_manager);
    
    assert(success1, 'Stream manager monitoring should succeed');
    assert(success2, 'Bridge adapter monitoring should succeed');
    assert(success3, 'Yield manager monitoring should succeed');
}

#[test]
fn test_alert_threshold_management() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Set custom alert thresholds
    let success1 = monitor.set_alert_threshold(AlertMetric::ErrorRate, 1000); // 10%
    let success2 = monitor.set_alert_threshold(AlertMetric::ResponseTime, 5000); // 5 seconds
    let success3 = monitor.set_alert_threshold(AlertMetric::BridgeFailures, 3);
    
    assert(success1, 'Error rate threshold should be set');
    assert(success2, 'Response time threshold should be set');
    assert(success3, 'Bridge failures threshold should be set');
}

#[test]
fn test_active_alerts() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Initially no alerts
    let alerts = monitor.get_active_alerts();
    assert(alerts.len() == 0, 'Should have no alerts initially');
    
    // After checking system health, there might be alerts
    monitor.check_system_health();
    
    let alerts_after = monitor.get_active_alerts();
    // The number of alerts depends on system state, so we just check it doesn't panic
}

#[test]
fn test_failure_detection() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Detect failures
    let failures = monitor.detect_failures();
    // Initially should have no failures
    assert(failures.len() == 0, 'Should have no failures initially');
}

#[test]
fn test_failure_detection_rules() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Create custom failure detection rules
    let mut rules = ArrayTrait::new();
    
    let rule1 = FailureRule {
        metric: AlertMetric::ErrorRate,
        threshold: 2000, // 20%
        time_window: 600, // 10 minutes
        failure_type: FailureType::SystemFailure,
        auto_recovery: true,
    };
    
    let rule2 = FailureRule {
        metric: AlertMetric::BridgeFailures,
        threshold: 10,
        time_window: 1800, // 30 minutes
        failure_type: FailureType::BridgeFailure,
        auto_recovery: false,
    };
    
    rules.append(rule1);
    rules.append(rule2);
    
    let success = monitor.set_failure_detection_rules(rules);
    assert(success, 'Setting failure rules should succeed');
}

#[test]
fn test_automatic_recovery() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Initiate automatic recovery for different failure types
    let success1 = monitor.initiate_automatic_recovery(FailureType::StreamFailure);
    let success2 = monitor.initiate_automatic_recovery(FailureType::BridgeFailure);
    let success3 = monitor.initiate_automatic_recovery(FailureType::YieldFailure);
    
    assert(success1, 'Stream failure recovery should succeed');
    assert(success2, 'Bridge failure recovery should succeed');
    assert(success3, 'Yield failure recovery should succeed');
}

#[test]
fn test_recovery_status_tracking() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Initiate recovery and check status
    monitor.initiate_automatic_recovery(FailureType::NetworkFailure);
    
    // Recovery ID should be 1 for first recovery
    let status = monitor.get_recovery_status(1);
    // Status should be either Completed or RequiresManualIntervention
    // depending on the recovery implementation
}

#[test]
fn test_error_handler_integration() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    let error_handler = contract_address_const::<'error_handler'>();
    
    // Set error handler
    let success = monitor.set_error_handler(error_handler);
    assert(success, 'Setting error handler should succeed');
}

#[test]
fn test_monitored_contract_management() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    let contract_addr = contract_address_const::<'test_contract'>();
    
    // Add contract to monitoring
    let success = monitor.add_monitored_contract(contract_addr, ContractType::StreamManager);
    assert(success, 'Adding monitored contract should succeed');
    
    // Remove contract from monitoring
    let success = monitor.remove_monitored_contract(contract_addr);
    assert(success, 'Removing monitored contract should succeed');
}

#[test]
#[should_panic(expected: ('Only owner can call',))]
fn test_monitoring_unauthorized() {
    let monitor = deploy_system_monitor();
    let unauthorized = contract_address_const::<'unauthorized'>();
    set_caller_address(unauthorized);
    
    let contract_addr = contract_address_const::<'test_contract'>();
    
    // Should fail for non-owner
    monitor.add_monitored_contract(contract_addr, ContractType::StreamManager);
}

#[test]
fn test_alert_acknowledgment() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Check system health to potentially generate alerts
    monitor.check_system_health();
    
    // Try to acknowledge a non-existent alert
    let success = monitor.acknowledge_alert(999);
    assert(!success, 'Acknowledging non-existent alert should fail');
    
    // If there are alerts, try to acknowledge the first one
    let alerts = monitor.get_active_alerts();
    if alerts.len() > 0 {
        let first_alert = alerts.at(0);
        let success = monitor.acknowledge_alert(first_alert.id);
        assert(success, 'Acknowledging existing alert should succeed');
    }
}

#[test]
fn test_comprehensive_monitoring_workflow() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    set_block_timestamp(1000);
    
    // Set up monitoring
    let stream_manager = contract_address_const::<'stream_manager'>();
    monitor.monitor_stream_manager(stream_manager);
    
    // Set custom thresholds
    monitor.set_alert_threshold(AlertMetric::ErrorRate, 500); // 5%
    monitor.set_alert_threshold(AlertMetric::ResponseTime, 2000); // 2 seconds
    
    // Set up failure detection rules
    let mut rules = ArrayTrait::new();
    let rule = FailureRule {
        metric: AlertMetric::SystemLoad,
        threshold: 9500, // 95%
        time_window: 300, // 5 minutes
        failure_type: FailureType::SystemFailure,
        auto_recovery: true,
    };
    rules.append(rule);
    monitor.set_failure_detection_rules(rules);
    
    // Perform health check
    let health = monitor.check_system_health();
    assert(matches!(health, SystemHealthStatus::Healthy), 'System should be healthy');
    
    // Get metrics
    let metrics = monitor.get_health_metrics();
    assert(metrics.last_updated == 1000, 'Metrics should be updated');
    
    // Check for failures
    let failures = monitor.detect_failures();
    // Should not have failures in a clean system
    
    // Get alerts
    let alerts = monitor.get_active_alerts();
    // Number of alerts depends on system state
}

#[test]
fn test_multiple_recovery_operations() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Initiate multiple recovery operations
    monitor.initiate_automatic_recovery(FailureType::StreamFailure);
    monitor.initiate_automatic_recovery(FailureType::BridgeFailure);
    monitor.initiate_automatic_recovery(FailureType::YieldFailure);
    
    // Check status of each recovery
    let status1 = monitor.get_recovery_status(1);
    let status2 = monitor.get_recovery_status(2);
    let status3 = monitor.get_recovery_status(3);
    
    // All should have some status (not NotStarted since we initiated them)
    // The exact status depends on the recovery implementation
}

#[test]
fn test_health_check_with_time_progression() {
    let monitor = deploy_system_monitor();
    let owner = contract_address_const::<'owner'>();
    set_caller_address(owner);
    
    // Initial health check
    set_block_timestamp(1000);
    let health1 = monitor.check_system_health();
    let metrics1 = monitor.get_health_metrics();
    
    // Health check after some time
    set_block_timestamp(2000);
    let health2 = monitor.check_system_health();
    let metrics2 = monitor.get_health_metrics();
    
    // Uptime should have increased
    assert(metrics2.system_uptime > metrics1.system_uptime, 'Uptime should increase');
    assert(metrics2.last_updated > metrics1.last_updated, 'Last updated should increase');
}