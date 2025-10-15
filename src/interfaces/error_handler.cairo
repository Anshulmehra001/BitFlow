use starknet::ContractAddress;
use crate::types::{BitFlowError, ErrorSeverity, ErrorContext, RecoveryPlan, SystemHealthStatus};

#[starknet::interface]
pub trait IErrorHandler<TContractState> {
    // Error reporting and handling
    fn report_error(
        ref self: TContractState,
        error_type: BitFlowError,
        severity: ErrorSeverity,
        additional_data: felt252
    ) -> u256;
    
    fn handle_error(ref self: TContractState, error_id: u256) -> bool;
    fn get_error_context(self: @TContractState, error_id: u256) -> ErrorContext;
    fn get_recovery_plan(self: @TContractState, error_type: BitFlowError) -> RecoveryPlan;
    
    // System health monitoring
    fn get_system_health_status(self: @TContractState) -> SystemHealthStatus;
    fn get_error_count_by_type(self: @TContractState, error_type: BitFlowError) -> u256;
    fn get_recent_errors(self: @TContractState, limit: u32) -> Array<ErrorContext>;
    
    // Emergency controls
    fn trigger_emergency_pause(ref self: TContractState, reason: felt252) -> bool;
    fn lift_emergency_pause(ref self: TContractState) -> bool;
    fn is_emergency_paused(self: @TContractState) -> bool;
    
    // Recovery operations
    fn initiate_recovery(ref self: TContractState, error_id: u256) -> bool;
    fn retry_failed_operation(ref self: TContractState, operation_id: u256) -> bool;
    fn escalate_error(ref self: TContractState, error_id: u256) -> bool;
    
    // Configuration
    fn update_recovery_plan(
        ref self: TContractState,
        error_type: BitFlowError,
        recovery_plan: RecoveryPlan
    ) -> bool;
    fn set_error_threshold(ref self: TContractState, error_type: BitFlowError, threshold: u256) -> bool;
}