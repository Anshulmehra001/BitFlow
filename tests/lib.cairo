// Test modules for BitFlow protocol
mod test_stream_manager;
mod test_escrow_manager;
mod test_yield_manager;
mod test_bridge_adapter;
mod test_subscription_manager;
mod test_utils;
mod test_defi_integrations;
mod test_yield_defi_integration;
mod test_micro_payment_manager;
mod test_content_pricing_manager;
mod test_integrated_micro_payment_system;
mod test_error_handler;
mod test_error_handling_utils;
mod test_system_monitor;
mod test_notification_system;

// End-to-End Testing Framework
mod e2e;

// Security Testing Framework
mod security {
    mod smart_contract_security_tests;
    mod api_penetration_tests;
    mod access_control_tests;
    mod vulnerability_scanner;
    mod audit_helpers;
    mod security_test_data;
    mod security_config;
    mod comprehensive_security_test;
}