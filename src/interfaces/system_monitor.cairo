use starknet::ContractAddress;
use crate::types::SystemHealthStatus;
use crate::contracts::system_monitor::{
    HealthMetrics, AlertMetric, Alert, FailureDetection, FailureRule, 
    FailureType, RecoveryStatus, ContractType
};

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