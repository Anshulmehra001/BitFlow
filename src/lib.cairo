// BitFlow - Cross-chain Bitcoin Payment Streaming Protocol
// Main library module that exports all core components

pub mod interfaces;
pub mod contracts;
pub mod types;
pub mod utils;

// Re-export core interfaces for easy access
pub use interfaces::{
    stream_manager::IStreamManager,
    escrow_manager::IEscrowManager,
    yield_manager::IYieldManager,
    bridge_adapter::IAtomiqBridgeAdapter,
    subscription_manager::ISubscriptionManager,
};

// Re-export core types
pub use types::{
    PaymentStream,
    Subscription,
    YieldPosition,
    BridgeStatus,
    SubscriptionStatus,
    BitFlowError,
};