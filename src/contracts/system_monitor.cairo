use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use crate::types::{BitFlowError, ErrorSeverity, SystemHealthStatus};
use crate::interfaces::error_handler::IErrorHandlerDispatcher;

#[starknet::interface]
pub trait ISystemMonitor<TContractState> {
    // Health monitoring
    fn check_system_health(ref self: TContractState) -> SystemHealthStatus;
    fn get_health_metrics(self: @TContractState) -> HealthMetrics;
    fn set_health_check_interval(ref self: TContractState, interval: u64) -> bool;
    
    // Component monitoring
    fn monitor_stream_manager(ref self: TContractState, stream_manager: ContractAddress) -> bool;
    fn monitor_bridge_adapter(ref self: TContractState, bridge_adapter: ContractAddress) -> bool;
    fn monitor_yield_manager(ref self: TContractState, yield_manager: ContractAddress) -> bool;
    
    // Alerting
    fn set_alert_threshold(ref self: TContractState, metric: AlertMetric, threshold: u256) -> bool;
    fn get_active_alerts(self: @TContractState) -> Array<Alert>;
    fn acknowledge_alert(ref self: TContractState, alert_id: u256) -> bool;
    
    // Failure detection
    fn detect_failures(ref self: TContractState) -> Array<FailureDetection>;
    fn set_failure_detection_rules(ref self: TContractState, rules: Array<FailureRule>) -> bool;
    
    // Recovery procedures
    fn initiate_automatic_recovery(ref self: TContractState, failure_type: FailureType) -> bool;
    fn get_recovery_status(self: @TContractState, recovery_id: u256) -> RecoveryStatus;
    
    // Configuration
    fn set_error_handler(ref self: TContractState, error_handler: ContractAddress) -> bool;
    fn add_monitored_contract(ref self: TContractState, contract_address: ContractAddress, contract_type: ContractType) -> bool;
    fn remove_monitored_contract(ref self: TContractState, contract_address: ContractAddress) -> bool;
}

#[derive(Drop, Serde, starknet::Store)]
pub struct HealthMetrics {
    pub system_uptime: u64,
    pub total_transactions: u256,
    pub failed_transactions: u256,
    pub average_response_time: u64,
    pub memory_usage: u256,
    pub active_streams: u256,
    pub bridge_success_rate: u256, // Percentage * 100
    pub yield_performance: u256,   // Percentage * 100
    pub last_updated: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum AlertMetric {
    ErrorRate,
    ResponseTime,
    MemoryUsage,
    FailedTransactions,
    BridgeFailures,
    YieldFailures,
    SystemLoad,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum AlertSeverity {
    Info,
    Warning,
    Critical,
    Emergency,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Alert {
    pub id: u256,
    pub metric: AlertMetric,
    pub severity: AlertSeverity,
    pub message: felt252,
    pub timestamp: u64,
    pub acknowledged: bool,
    pub resolved: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum FailureType {
    StreamFailure,
    BridgeFailure,
    YieldFailure,
    NetworkFailure,
    StorageFailure,
    ContractFailure,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct FailureDetection {
    pub id: u256,
    pub failure_type: FailureType,
    pub affected_contract: ContractAddress,
    pub detection_time: u64,
    pub severity: ErrorSeverity,
    pub auto_recovery_attempted: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct FailureRule {
    pub metric: AlertMetric,
    pub threshold: u256,
    pub time_window: u64,
    pub failure_type: FailureType,
    pub auto_recovery: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum RecoveryStatus {
    NotStarted,
    InProgress,
    Completed,
    Failed,
    RequiresManualIntervention,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum ContractType {
    StreamManager,
    BridgeAdapter,
    YieldManager,
    EscrowManager,
    SubscriptionManager,
    ErrorHandler,
}

#[starknet::contract]
pub mod SystemMonitor {
    use super::*;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };

    #[storage]
    struct Storage {
        // Health monitoring
        health_metrics: HealthMetrics,
        health_check_interval: u64,
        last_health_check: u64,
        system_start_time: u64,
        
        // Monitored contracts
        monitored_contracts: Map<ContractAddress, ContractType>,
        contract_health: Map<ContractAddress, bool>,
        
        // Alerting
        alerts: Map<u256, Alert>,
        next_alert_id: u256,
        alert_thresholds: Map<AlertMetric, u256>,
        
        // Failure detection
        failure_detections: Map<u256, FailureDetection>,
        next_failure_id: u256,
        failure_rules: Map<u256, FailureRule>,
        next_rule_id: u256,
        
        // Recovery tracking
        recovery_operations: Map<u256, RecoveryStatus>,
        next_recovery_id: u256,
        
        // Configuration
        error_handler: ContractAddress,
        owner: ContractAddress,
        
        // Metrics tracking
        transaction_count: u256,
        failed_transaction_count: u256,
        response_times: Map<u256, u64>, // Rolling window of response times
        response_time_index: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        HealthCheckCompleted: HealthCheckCompleted,
        AlertTriggered: AlertTriggered,
        AlertResolved: AlertResolved,
        FailureDetected: FailureDetected,
        RecoveryInitiated: RecoveryInitiated,
        RecoveryCompleted: RecoveryCompleted,
        ContractMonitoringStarted: ContractMonitoringStarted,
        ContractMonitoringStopped: ContractMonitoringStopped,
    }

    #[derive(Drop, starknet::Event)]
    pub struct HealthCheckCompleted {
        pub timestamp: u64,
        pub health_status: SystemHealthStatus,
        pub metrics: HealthMetrics,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AlertTriggered {
        pub alert_id: u256,
        pub metric: AlertMetric,
        pub severity: AlertSeverity,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AlertResolved {
        pub alert_id: u256,
        pub resolution_time: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FailureDetected {
        pub failure_id: u256,
        pub failure_type: FailureType,
        pub affected_contract: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RecoveryInitiated {
        pub recovery_id: u256,
        pub failure_type: FailureType,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RecoveryCompleted {
        pub recovery_id: u256,
        pub success: bool,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContractMonitoringStarted {
        pub contract_address: ContractAddress,
        pub contract_type: ContractType,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContractMonitoringStopped {
        pub contract_address: ContractAddress,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.system_start_time.write(get_block_timestamp());
        self.health_check_interval.write(300); // 5 minutes default
        self.next_alert_id.write(1);
        self.next_failure_id.write(1);
        self.next_rule_id.write(1);
        self.next_recovery_id.write(1);
        
        // Initialize default health metrics
        let initial_metrics = HealthMetrics {
            system_uptime: 0,
            total_transactions: 0,
            failed_transactions: 0,
            average_response_time: 0,
            memory_usage: 0,
            active_streams: 0,
            bridge_success_rate: 10000, // 100%
            yield_performance: 10000,   // 100%
            last_updated: get_block_timestamp(),
        };
        self.health_metrics.write(initial_metrics);
        
        // Set default alert thresholds
        self._set_default_alert_thresholds();
        self._set_default_failure_rules();
    }

    #[abi(embed_v0)]
    impl SystemMonitorImpl of ISystemMonitor<ContractState> {
        fn check_system_health(ref self: ContractState) -> SystemHealthStatus {
            let current_time = get_block_timestamp();
            let mut metrics = self.health_metrics.read();
            
            // Update uptime
            metrics.system_uptime = current_time - self.system_start_time.read();
            
            // Calculate error rate
            let error_rate = if metrics.total_transactions > 0 {
                (metrics.failed_transactions * 10000) / metrics.total_transactions
            } else {
                0
            };
            
            // Calculate average response time
            metrics.average_response_time = self._calculate_average_response_time();
            
            // Update last check time
            metrics.last_updated = current_time;
            self.health_metrics.write(metrics);
            self.last_health_check.write(current_time);
            
            // Determine health status
            let health_status = if error_rate > 1000 { // > 10%
                SystemHealthStatus::Critical
            } else if error_rate > 500 { // > 5%
                SystemHealthStatus::Degraded
            } else if metrics.average_response_time > 5000 { // > 5 seconds
                SystemHealthStatus::Degraded
            } else {
                SystemHealthStatus::Healthy
            };
            
            // Check for alerts
            self._check_alert_conditions();
            
            // Emit event
            self.emit(HealthCheckCompleted {
                timestamp: current_time,
                health_status,
                metrics,
            });
            
            health_status
        }

        fn get_health_metrics(self: @ContractState) -> HealthMetrics {
            self.health_metrics.read()
        }

        fn set_health_check_interval(ref self: ContractState, interval: u64) -> bool {
            self._assert_owner();
            self.health_check_interval.write(interval);
            true
        }

        fn monitor_stream_manager(ref self: ContractState, stream_manager: ContractAddress) -> bool {
            self._assert_owner();
            self.monitored_contracts.entry(stream_manager).write(ContractType::StreamManager);
            self.contract_health.entry(stream_manager).write(true);
            
            self.emit(ContractMonitoringStarted {
                contract_address: stream_manager,
                contract_type: ContractType::StreamManager,
                timestamp: get_block_timestamp(),
            });
            
            true
        }

        fn monitor_bridge_adapter(ref self: ContractState, bridge_adapter: ContractAddress) -> bool {
            self._assert_owner();
            self.monitored_contracts.entry(bridge_adapter).write(ContractType::BridgeAdapter);
            self.contract_health.entry(bridge_adapter).write(true);
            
            self.emit(ContractMonitoringStarted {
                contract_address: bridge_adapter,
                contract_type: ContractType::BridgeAdapter,
                timestamp: get_block_timestamp(),
            });
            
            true
        }

        fn monitor_yield_manager(ref self: ContractState, yield_manager: ContractAddress) -> bool {
            self._assert_owner();
            self.monitored_contracts.entry(yield_manager).write(ContractType::YieldManager);
            self.contract_health.entry(yield_manager).write(true);
            
            self.emit(ContractMonitoringStarted {
                contract_address: yield_manager,
                contract_type: ContractType::YieldManager,
                timestamp: get_block_timestamp(),
            });
            
            true
        }

        fn set_alert_threshold(ref self: ContractState, metric: AlertMetric, threshold: u256) -> bool {
            self._assert_owner();
            self.alert_thresholds.entry(metric).write(threshold);
            true
        }

        fn get_active_alerts(self: @ContractState) -> Array<Alert> {
            let mut alerts = ArrayTrait::new();
            let current_id = self.next_alert_id.read();
            
            let mut i = 1;
            while i < current_id {
                let alert = self.alerts.entry(i).read();
                if alert.id != 0 && !alert.resolved {
                    alerts.append(alert);
                }
                i += 1;
            };
            
            alerts
        }

        fn acknowledge_alert(ref self: ContractState, alert_id: u256) -> bool {
            self._assert_owner();
            
            let mut alert = self.alerts.entry(alert_id).read();
            if alert.id == 0 {
                return false;
            }
            
            alert.acknowledged = true;
            self.alerts.entry(alert_id).write(alert);
            true
        }

        fn detect_failures(ref self: ContractState) -> Array<FailureDetection> {
            let mut failures = ArrayTrait::new();
            
            // Check each monitored contract
            // This would involve calling health check functions on each contract
            // For now, we'll implement basic failure detection logic
            
            let current_time = get_block_timestamp();
            let metrics = self.health_metrics.read();
            
            // Detect high error rate
            if metrics.total_transactions > 0 {
                let error_rate = (metrics.failed_transactions * 10000) / metrics.total_transactions;
                if error_rate > 1000 { // > 10%
                    let failure_id = self.next_failure_id.read();
                    let failure = FailureDetection {
                        id: failure_id,
                        failure_type: FailureType::NetworkFailure,
                        affected_contract: get_caller_address(),
                        detection_time: current_time,
                        severity: ErrorSeverity::High,
                        auto_recovery_attempted: false,
                    };
                    
                    self.failure_detections.entry(failure_id).write(failure);
                    self.next_failure_id.write(failure_id + 1);
                    failures.append(failure);
                    
                    self.emit(FailureDetected {
                        failure_id,
                        failure_type: FailureType::NetworkFailure,
                        affected_contract: get_caller_address(),
                        timestamp: current_time,
                    });
                }
            }
            
            failures
        }

        fn set_failure_detection_rules(ref self: ContractState, rules: Array<FailureRule>) -> bool {
            self._assert_owner();
            
            let mut i = 0;
            while i < rules.len() {
                let rule = *rules.at(i);
                let rule_id = self.next_rule_id.read();
                self.failure_rules.entry(rule_id).write(rule);
                self.next_rule_id.write(rule_id + 1);
                i += 1;
            };
            
            true
        }

        fn initiate_automatic_recovery(ref self: ContractState, failure_type: FailureType) -> bool {
            let recovery_id = self.next_recovery_id.read();
            self.recovery_operations.entry(recovery_id).write(RecoveryStatus::InProgress);
            self.next_recovery_id.write(recovery_id + 1);
            
            self.emit(RecoveryInitiated {
                recovery_id,
                failure_type,
                timestamp: get_block_timestamp(),
            });
            
            // Implement recovery logic based on failure type
            let success = match failure_type {
                FailureType::StreamFailure => self._recover_stream_failures(),
                FailureType::BridgeFailure => self._recover_bridge_failures(),
                FailureType::YieldFailure => self._recover_yield_failures(),
                FailureType::NetworkFailure => self._recover_network_failures(),
                FailureType::StorageFailure => self._recover_storage_failures(),
                FailureType::ContractFailure => self._recover_contract_failures(),
            };
            
            let final_status = if success {
                RecoveryStatus::Completed
            } else {
                RecoveryStatus::RequiresManualIntervention
            };
            
            self.recovery_operations.entry(recovery_id).write(final_status);
            
            self.emit(RecoveryCompleted {
                recovery_id,
                success,
                timestamp: get_block_timestamp(),
            });
            
            success
        }

        fn get_recovery_status(self: @ContractState, recovery_id: u256) -> RecoveryStatus {
            self.recovery_operations.entry(recovery_id).read()
        }

        fn set_error_handler(ref self: ContractState, error_handler: ContractAddress) -> bool {
            self._assert_owner();
            self.error_handler.write(error_handler);
            true
        }

        fn add_monitored_contract(
            ref self: ContractState,
            contract_address: ContractAddress,
            contract_type: ContractType
        ) -> bool {
            self._assert_owner();
            self.monitored_contracts.entry(contract_address).write(contract_type);
            self.contract_health.entry(contract_address).write(true);
            
            self.emit(ContractMonitoringStarted {
                contract_address,
                contract_type,
                timestamp: get_block_timestamp(),
            });
            
            true
        }

        fn remove_monitored_contract(ref self: ContractState, contract_address: ContractAddress) -> bool {
            self._assert_owner();
            // Note: In Cairo, we can't actually delete from storage, so we mark as inactive
            self.contract_health.entry(contract_address).write(false);
            
            self.emit(ContractMonitoringStopped {
                contract_address,
                timestamp: get_block_timestamp(),
            });
            
            true
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_owner(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can call');
        }

        fn _set_default_alert_thresholds(ref self: ContractState) {
            self.alert_thresholds.entry(AlertMetric::ErrorRate).write(500); // 5%
            self.alert_thresholds.entry(AlertMetric::ResponseTime).write(3000); // 3 seconds
            self.alert_thresholds.entry(AlertMetric::MemoryUsage).write(8000); // 80%
            self.alert_thresholds.entry(AlertMetric::FailedTransactions).write(10);
            self.alert_thresholds.entry(AlertMetric::BridgeFailures).write(5);
            self.alert_thresholds.entry(AlertMetric::YieldFailures).write(3);
            self.alert_thresholds.entry(AlertMetric::SystemLoad).write(9000); // 90%
        }

        fn _set_default_failure_rules(ref self: ContractState) {
            // High error rate rule
            let error_rate_rule = FailureRule {
                metric: AlertMetric::ErrorRate,
                threshold: 1000, // 10%
                time_window: 300, // 5 minutes
                failure_type: FailureType::NetworkFailure,
                auto_recovery: true,
            };
            
            let rule_id = self.next_rule_id.read();
            self.failure_rules.entry(rule_id).write(error_rate_rule);
            self.next_rule_id.write(rule_id + 1);
            
            // Bridge failure rule
            let bridge_rule = FailureRule {
                metric: AlertMetric::BridgeFailures,
                threshold: 5,
                time_window: 600, // 10 minutes
                failure_type: FailureType::BridgeFailure,
                auto_recovery: true,
            };
            
            let rule_id = self.next_rule_id.read();
            self.failure_rules.entry(rule_id).write(bridge_rule);
            self.next_rule_id.write(rule_id + 1);
        }

        fn _calculate_average_response_time(self: @ContractState) -> u64 {
            let mut total_time = 0_u64;
            let mut count = 0_u64;
            let current_index = self.response_time_index.read();
            
            // Calculate average from last 100 response times
            let start_index = if current_index > 100 { current_index - 100 } else { 0 };
            
            let mut i = start_index;
            while i < current_index {
                let response_time = self.response_times.entry(i).read();
                if response_time > 0 {
                    total_time += response_time;
                    count += 1;
                }
                i += 1;
            };
            
            if count > 0 {
                total_time / count
            } else {
                0
            }
        }

        fn _check_alert_conditions(ref self: ContractState) {
            let metrics = self.health_metrics.read();
            let current_time = get_block_timestamp();
            
            // Check error rate
            if metrics.total_transactions > 0 {
                let error_rate = (metrics.failed_transactions * 10000) / metrics.total_transactions;
                let threshold = self.alert_thresholds.entry(AlertMetric::ErrorRate).read();
                
                if error_rate > threshold {
                    self._trigger_alert(
                        AlertMetric::ErrorRate,
                        AlertSeverity::Warning,
                        'High error rate detected'
                    );
                }
            }
            
            // Check response time
            let response_threshold = self.alert_thresholds.entry(AlertMetric::ResponseTime).read();
            if metrics.average_response_time > response_threshold {
                self._trigger_alert(
                    AlertMetric::ResponseTime,
                    AlertSeverity::Warning,
                    'High response time detected'
                );
            }
        }

        fn _trigger_alert(
            ref self: ContractState,
            metric: AlertMetric,
            severity: AlertSeverity,
            message: felt252
        ) {
            let alert_id = self.next_alert_id.read();
            let alert = Alert {
                id: alert_id,
                metric,
                severity,
                message,
                timestamp: get_block_timestamp(),
                acknowledged: false,
                resolved: false,
            };
            
            self.alerts.entry(alert_id).write(alert);
            self.next_alert_id.write(alert_id + 1);
            
            self.emit(AlertTriggered {
                alert_id,
                metric,
                severity,
                timestamp: get_block_timestamp(),
            });
            
            // Report to error handler if configured
            let error_handler_addr = self.error_handler.read();
            if !error_handler_addr.is_zero() {
                let error_handler = IErrorHandlerDispatcher { contract_address: error_handler_addr };
                error_handler.report_error(
                    BitFlowError::SystemOverloaded,
                    ErrorSeverity::Medium,
                    message
                );
            }
        }

        fn _recover_stream_failures(ref self: ContractState) -> bool {
            // Implement stream failure recovery logic
            // This would involve restarting failed streams, clearing stuck transactions, etc.
            true
        }

        fn _recover_bridge_failures(ref self: ContractState) -> bool {
            // Implement bridge failure recovery logic
            // This would involve retrying failed bridge transactions, switching to backup bridges, etc.
            true
        }

        fn _recover_yield_failures(ref self: ContractState) -> bool {
            // Implement yield failure recovery logic
            // This would involve switching yield protocols, unstaking from failed protocols, etc.
            true
        }

        fn _recover_network_failures(ref self: ContractState) -> bool {
            // Implement network failure recovery logic
            // This would involve reconnecting to network, clearing network caches, etc.
            true
        }

        fn _recover_storage_failures(ref self: ContractState) -> bool {
            // Implement storage failure recovery logic
            // This would involve data consistency checks, backup restoration, etc.
            false // Usually requires manual intervention
        }

        fn _recover_contract_failures(ref self: ContractState) -> bool {
            // Implement contract failure recovery logic
            // This would involve contract state validation, emergency procedures, etc.
            false // Usually requires manual intervention
        }
    }
}