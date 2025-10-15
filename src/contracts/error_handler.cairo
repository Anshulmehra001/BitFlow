use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use crate::types::{BitFlowError, ErrorSeverity, ErrorContext, RecoveryAction, RecoveryPlan, SystemHealthStatus};

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



#[derive(Drop, Serde, starknet::Store)]
pub struct FailedOperation {
    pub id: u256,
    pub operation_type: felt252,
    pub contract_address: ContractAddress,
    pub parameters: Array<felt252>,
    pub retry_count: u8,
    pub last_retry_time: u64,
    pub error_type: BitFlowError,
}

#[starknet::contract]
pub mod ErrorHandler {
    use super::*;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };

    #[storage]
    struct Storage {
        // Error tracking
        errors: Map<u256, ErrorContext>,
        next_error_id: u256,
        error_counts: Map<BitFlowError, u256>,
        
        // Recovery plans and thresholds
        recovery_plans: Map<BitFlowError, RecoveryPlan>,
        error_thresholds: Map<BitFlowError, u256>,
        
        // Failed operations for retry
        failed_operations: Map<u256, FailedOperation>,
        next_operation_id: u256,
        
        // System state
        emergency_paused: bool,
        emergency_reason: felt252,
        emergency_timestamp: u64,
        system_health: SystemHealthStatus,
        
        // Access control
        owner: ContractAddress,
        authorized_contracts: Map<ContractAddress, bool>,
        
        // Monitoring
        last_health_check: u64,
        total_errors_24h: u256,
        critical_errors_count: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ErrorReported: ErrorReported,
        ErrorHandled: ErrorHandled,
        EmergencyPauseTriggered: EmergencyPauseTriggered,
        EmergencyPauseLifted: EmergencyPauseLifted,
        RecoveryInitiated: RecoveryInitiated,
        OperationRetried: OperationRetried,
        SystemHealthChanged: SystemHealthChanged,
        ErrorEscalated: ErrorEscalated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ErrorReported {
        pub error_id: u256,
        pub error_type: BitFlowError,
        pub severity: ErrorSeverity,
        pub contract_address: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ErrorHandled {
        pub error_id: u256,
        pub recovery_action: RecoveryAction,
        pub success: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EmergencyPauseTriggered {
        pub reason: felt252,
        pub timestamp: u64,
        pub triggered_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EmergencyPauseLifted {
        pub timestamp: u64,
        pub lifted_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RecoveryInitiated {
        pub error_id: u256,
        pub recovery_action: RecoveryAction,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OperationRetried {
        pub operation_id: u256,
        pub retry_count: u8,
        pub success: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SystemHealthChanged {
        pub old_status: SystemHealthStatus,
        pub new_status: SystemHealthStatus,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ErrorEscalated {
        pub error_id: u256,
        pub escalation_level: u8,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.next_error_id.write(1);
        self.next_operation_id.write(1);
        self.emergency_paused.write(false);
        self.system_health.write(SystemHealthStatus::Healthy);
        self.last_health_check.write(get_block_timestamp());
        
        // Initialize default recovery plans
        self._initialize_default_recovery_plans();
    }

    #[abi(embed_v0)]
    impl ErrorHandlerImpl of IErrorHandler<ContractState> {
        fn report_error(
            ref self: ContractState,
            error_type: BitFlowError,
            severity: ErrorSeverity,
            additional_data: felt252
        ) -> u256 {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            let error_id = self.next_error_id.read();
            
            // Create error context
            let error_context = ErrorContext {
                error_type,
                severity,
                timestamp,
                contract_address: caller,
                caller,
                additional_data,
            };
            
            // Store error
            self.errors.entry(error_id).write(error_context);
            self.next_error_id.write(error_id + 1);
            
            // Update error counts
            let current_count = self.error_counts.entry(error_type).read();
            self.error_counts.entry(error_type).write(current_count + 1);
            
            // Update 24h error count
            self.total_errors_24h.write(self.total_errors_24h.read() + 1);
            
            // Track critical errors
            if matches!(severity, ErrorSeverity::Critical) {
                self.critical_errors_count.write(self.critical_errors_count.read() + 1);
            }
            
            // Check if error threshold is exceeded
            self._check_error_threshold(error_type);
            
            // Update system health
            self._update_system_health();
            
            // Emit event
            self.emit(ErrorReported {
                error_id,
                error_type,
                severity,
                contract_address: caller,
                timestamp,
            });
            
            // Auto-handle if recovery plan exists
            self._auto_handle_error(error_id);
            
            error_id
        }

        fn handle_error(ref self: ContractState, error_id: u256) -> bool {
            let error_context = self.errors.entry(error_id).read();
            assert(error_context.timestamp != 0, 'Error not found');
            
            let recovery_plan = self.recovery_plans.entry(error_context.error_type).read();
            let success = self._execute_recovery_action(error_id, recovery_plan.action);
            
            self.emit(ErrorHandled {
                error_id,
                recovery_action: recovery_plan.action,
                success,
            });
            
            success
        }

        fn get_error_context(self: @ContractState, error_id: u256) -> ErrorContext {
            let error_context = self.errors.entry(error_id).read();
            assert(error_context.timestamp != 0, 'Error not found');
            error_context
        }

        fn get_recovery_plan(self: @ContractState, error_type: BitFlowError) -> RecoveryPlan {
            self.recovery_plans.entry(error_type).read()
        }

        fn get_system_health_status(self: @ContractState) -> SystemHealthStatus {
            self.system_health.read()
        }

        fn get_error_count_by_type(self: @ContractState, error_type: BitFlowError) -> u256 {
            self.error_counts.entry(error_type).read()
        }

        fn get_recent_errors(self: @ContractState, limit: u32) -> Array<ErrorContext> {
            let mut errors = ArrayTrait::new();
            let current_id = self.next_error_id.read();
            let start_id = if current_id > limit.into() { current_id - limit.into() } else { 1 };
            
            let mut i = start_id;
            while i < current_id && errors.len() < limit {
                let error_context = self.errors.entry(i).read();
                if error_context.timestamp != 0 {
                    errors.append(error_context);
                }
                i += 1;
            };
            
            errors
        }

        fn trigger_emergency_pause(ref self: ContractState, reason: felt252) -> bool {
            self._assert_authorized();
            
            self.emergency_paused.write(true);
            self.emergency_reason.write(reason);
            self.emergency_timestamp.write(get_block_timestamp());
            
            // Update system health to emergency
            let old_health = self.system_health.read();
            self.system_health.write(SystemHealthStatus::Emergency);
            
            self.emit(EmergencyPauseTriggered {
                reason,
                timestamp: get_block_timestamp(),
                triggered_by: get_caller_address(),
            });
            
            self.emit(SystemHealthChanged {
                old_status: old_health,
                new_status: SystemHealthStatus::Emergency,
                timestamp: get_block_timestamp(),
            });
            
            true
        }

        fn lift_emergency_pause(ref self: ContractState) -> bool {
            self._assert_owner();
            assert(self.emergency_paused.read(), 'No emergency pause active');
            
            self.emergency_paused.write(false);
            self.emergency_reason.write(0);
            self.emergency_timestamp.write(0);
            
            // Reset system health
            let old_health = self.system_health.read();
            self.system_health.write(SystemHealthStatus::Healthy);
            
            self.emit(EmergencyPauseLifted {
                timestamp: get_block_timestamp(),
                lifted_by: get_caller_address(),
            });
            
            self.emit(SystemHealthChanged {
                old_status: old_health,
                new_status: SystemHealthStatus::Healthy,
                timestamp: get_block_timestamp(),
            });
            
            true
        }

        fn is_emergency_paused(self: @ContractState) -> bool {
            self.emergency_paused.read()
        }

        fn initiate_recovery(ref self: ContractState, error_id: u256) -> bool {
            self._assert_authorized();
            
            let error_context = self.errors.entry(error_id).read();
            assert(error_context.timestamp != 0, 'Error not found');
            
            let recovery_plan = self.recovery_plans.entry(error_context.error_type).read();
            
            self.emit(RecoveryInitiated {
                error_id,
                recovery_action: recovery_plan.action,
                timestamp: get_block_timestamp(),
            });
            
            self._execute_recovery_action(error_id, recovery_plan.action)
        }

        fn retry_failed_operation(ref self: ContractState, operation_id: u256) -> bool {
            let mut operation = self.failed_operations.entry(operation_id).read();
            assert(operation.id != 0, 'Operation not found');
            
            let recovery_plan = self.recovery_plans.entry(operation.error_type).read();
            
            // Check if max retries exceeded
            if operation.retry_count >= recovery_plan.max_retries {
                return false;
            }
            
            // Check retry delay
            let current_time = get_block_timestamp();
            if current_time - operation.last_retry_time < recovery_plan.retry_delay {
                return false;
            }
            
            // Increment retry count
            operation.retry_count += 1;
            operation.last_retry_time = current_time;
            self.failed_operations.entry(operation_id).write(operation);
            
            // Attempt retry (this would call the original operation)
            let success = self._retry_operation(operation_id);
            
            self.emit(OperationRetried {
                operation_id,
                retry_count: operation.retry_count,
                success,
            });
            
            success
        }

        fn escalate_error(ref self: ContractState, error_id: u256) -> bool {
            self._assert_authorized();
            
            let error_context = self.errors.entry(error_id).read();
            assert(error_context.timestamp != 0, 'Error not found');
            
            // Escalate based on current severity
            let escalated = match error_context.severity {
                ErrorSeverity::Low => {
                    // Escalate to medium - increase monitoring
                    true
                },
                ErrorSeverity::Medium => {
                    // Escalate to high - trigger alerts
                    true
                },
                ErrorSeverity::High => {
                    // Escalate to critical - emergency procedures
                    self.trigger_emergency_pause('Error escalated to critical');
                    true
                },
                ErrorSeverity::Critical => {
                    // Already at highest level
                    false
                },
            };
            
            if escalated {
                self.emit(ErrorEscalated {
                    error_id,
                    escalation_level: 1,
                    timestamp: get_block_timestamp(),
                });
            }
            
            escalated
        }

        fn update_recovery_plan(
            ref self: ContractState,
            error_type: BitFlowError,
            recovery_plan: RecoveryPlan
        ) -> bool {
            self._assert_owner();
            self.recovery_plans.entry(error_type).write(recovery_plan);
            true
        }

        fn set_error_threshold(
            ref self: ContractState,
            error_type: BitFlowError,
            threshold: u256
        ) -> bool {
            self._assert_owner();
            self.error_thresholds.entry(error_type).write(threshold);
            true
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_owner(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can call');
        }

        fn _assert_authorized(self: @ContractState) {
            let caller = get_caller_address();
            assert(
                caller == self.owner.read() || self.authorized_contracts.entry(caller).read(),
                'Unauthorized caller'
            );
        }

        fn _initialize_default_recovery_plans(ref self: ContractState) {
            // Stream errors - retry with backoff
            self.recovery_plans.entry(BitFlowError::StreamNotFound).write(
                RecoveryPlan {
                    action: RecoveryAction::Retry,
                    max_retries: 3,
                    retry_delay: 60,
                    escalation_threshold: 5,
                    requires_manual_approval: false,
                }
            );
            
            // Bridge errors - pause and manual intervention
            self.recovery_plans.entry(BitFlowError::BridgeFailure).write(
                RecoveryPlan {
                    action: RecoveryAction::Pause,
                    max_retries: 1,
                    retry_delay: 300,
                    escalation_threshold: 3,
                    requires_manual_approval: true,
                }
            );
            
            // Critical system errors - emergency stop
            self.recovery_plans.entry(BitFlowError::SystemOverloaded).write(
                RecoveryPlan {
                    action: RecoveryAction::EmergencyStop,
                    max_retries: 0,
                    retry_delay: 0,
                    escalation_threshold: 1,
                    requires_manual_approval: true,
                }
            );
            
            // Yield protocol errors - rollback and retry
            self.recovery_plans.entry(BitFlowError::YieldProtocolError).write(
                RecoveryPlan {
                    action: RecoveryAction::Rollback,
                    max_retries: 2,
                    retry_delay: 120,
                    escalation_threshold: 4,
                    requires_manual_approval: false,
                }
            );
        }

        fn _check_error_threshold(ref self: ContractState, error_type: BitFlowError) {
            let threshold = self.error_thresholds.entry(error_type).read();
            if threshold == 0 {
                return; // No threshold set
            }
            
            let count = self.error_counts.entry(error_type).read();
            if count >= threshold {
                // Threshold exceeded - trigger emergency pause
                self.trigger_emergency_pause('Error threshold exceeded');
            }
        }

        fn _update_system_health(ref self: ContractState) {
            let current_health = self.system_health.read();
            let critical_errors = self.critical_errors_count.read();
            let total_errors = self.total_errors_24h.read();
            
            let new_health = if critical_errors > 0 {
                SystemHealthStatus::Critical
            } else if total_errors > 100 {
                SystemHealthStatus::Degraded
            } else {
                SystemHealthStatus::Healthy
            };
            
            if !matches!(current_health, new_health) {
                self.system_health.write(new_health);
                self.emit(SystemHealthChanged {
                    old_status: current_health,
                    new_status: new_health,
                    timestamp: get_block_timestamp(),
                });
            }
        }

        fn _auto_handle_error(ref self: ContractState, error_id: u256) {
            let error_context = self.errors.entry(error_id).read();
            let recovery_plan = self.recovery_plans.entry(error_context.error_type).read();
            
            // Only auto-handle if no manual approval required
            if !recovery_plan.requires_manual_approval {
                self._execute_recovery_action(error_id, recovery_plan.action);
            }
        }

        fn _execute_recovery_action(
            ref self: ContractState,
            error_id: u256,
            action: RecoveryAction
        ) -> bool {
            match action {
                RecoveryAction::Retry => {
                    // Create failed operation for retry
                    self._create_failed_operation(error_id);
                    true
                },
                RecoveryAction::Pause => {
                    // Pause affected systems
                    self._pause_affected_systems(error_id);
                    true
                },
                RecoveryAction::Rollback => {
                    // Rollback recent changes
                    self._rollback_changes(error_id);
                    true
                },
                RecoveryAction::EmergencyStop => {
                    // Trigger emergency pause
                    self.trigger_emergency_pause('Recovery action: Emergency stop');
                    true
                },
                RecoveryAction::ManualIntervention => {
                    // Log for manual intervention
                    false
                },
                RecoveryAction::NoAction => {
                    // Do nothing
                    true
                },
            }
        }

        fn _create_failed_operation(ref self: ContractState, error_id: u256) {
            let operation_id = self.next_operation_id.read();
            let error_context = self.errors.entry(error_id).read();
            
            let failed_operation = FailedOperation {
                id: operation_id,
                operation_type: 'generic_operation',
                contract_address: error_context.contract_address,
                parameters: ArrayTrait::new(),
                retry_count: 0,
                last_retry_time: 0,
                error_type: error_context.error_type,
            };
            
            self.failed_operations.entry(operation_id).write(failed_operation);
            self.next_operation_id.write(operation_id + 1);
        }

        fn _pause_affected_systems(ref self: ContractState, error_id: u256) {
            // Implementation would pause specific systems based on error type
            // This is a placeholder for the actual pause logic
        }

        fn _rollback_changes(ref self: ContractState, error_id: u256) {
            // Implementation would rollback recent changes
            // This is a placeholder for the actual rollback logic
        }

        fn _retry_operation(ref self: ContractState, operation_id: u256) -> bool {
            // Implementation would retry the failed operation
            // This is a placeholder for the actual retry logic
            true
        }
    }
}