use starknet::ContractAddress;

// Core data structures for BitFlow protocol

#[derive(Drop, Serde, starknet::Store)]
pub struct PaymentStream {
    pub id: u256,
    pub sender: ContractAddress,
    pub recipient: ContractAddress,
    pub total_amount: u256,
    pub rate_per_second: u256,
    pub start_time: u64,
    pub end_time: u64,
    pub withdrawn_amount: u256,
    pub is_active: bool,
    pub yield_enabled: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Subscription {
    pub id: u256,
    pub plan_id: u256,
    pub subscriber: ContractAddress,
    pub provider: ContractAddress,
    pub stream_id: u256,
    pub start_time: u64,
    pub end_time: u64,
    pub auto_renew: bool,
    pub status: SubscriptionStatus,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct YieldPosition {
    pub stream_id: u256,
    pub protocol: ContractAddress,
    pub staked_amount: u256,
    pub earned_yield: u256,
    pub last_update: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum BridgeStatus {
    Pending,
    Confirmed,
    Failed,
    Cancelled,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum SubscriptionStatus {
    Active,
    Paused,
    Cancelled,
    Expired,
}

#[derive(Drop, Serde, PartialEq)]
pub enum BitFlowError {
    // Stream errors
    InsufficientBalance,
    StreamNotFound,
    StreamAlreadyExists,
    StreamNotActive,
    StreamPaused,
    StreamExpired,
    StreamCancelled,
    
    // Access control errors
    UnauthorizedAccess,
    InvalidCaller,
    ContractNotAuthorized,
    
    // Parameter validation errors
    InvalidParameters,
    InvalidTimeRange,
    ZeroAmount,
    AmountTooLarge,
    InvalidAddress,
    InvalidRate,
    InvalidDuration,
    
    // Bridge errors
    BridgeFailure,
    BridgePaused,
    BridgeTimeout,
    BridgeTransactionNotFound,
    BridgeInsufficientConfirmations,
    BitcoinTransactionAlreadyUsed,
    InvalidBitcoinTransaction,
    
    // Yield protocol errors
    YieldProtocolError,
    YieldProtocolUnavailable,
    YieldInsufficientLiquidity,
    YieldSlippageTooHigh,
    YieldProtocolPaused,
    
    // System errors
    ContractPaused,
    SystemOverloaded,
    InsufficientGas,
    StorageError,
    
    // Recovery errors
    RecoveryInProgress,
    RecoveryFailed,
    EmergencyPauseActive,
    
    // Subscription errors
    SubscriptionNotFound,
    SubscriptionExpired,
    SubscriptionAlreadyCancelled,
    InvalidSubscriptionPlan,
    
    // Micro-payment errors
    MicroPaymentFailed,
    ContentNotFound,
    InsufficientCredit,
    PricingNotSet,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum ErrorSeverity {
    Low,      // Warning, system continues normally
    Medium,   // Error, affects single operation
    High,     // Critical error, affects multiple operations
    Critical, // System-wide failure, emergency procedures needed
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ErrorContext {
    pub error_type: BitFlowError,
    pub severity: ErrorSeverity,
    pub timestamp: u64,
    pub contract_address: ContractAddress,
    pub caller: ContractAddress,
    pub additional_data: felt252, // Can store error-specific data
}

#[derive(Drop, Serde, starknet::Store)]
pub enum RecoveryAction {
    Retry,
    Pause,
    Rollback,
    EmergencyStop,
    ManualIntervention,
    NoAction,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct RecoveryPlan {
    pub action: RecoveryAction,
    pub max_retries: u8,
    pub retry_delay: u64, // seconds
    pub escalation_threshold: u8,
    pub requires_manual_approval: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum SystemHealthStatus {
    Healthy,
    Degraded,
    Critical,
    Emergency,
}