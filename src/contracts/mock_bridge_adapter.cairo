use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use crate::interfaces::bridge_adapter::IAtomiqBridgeAdapter;
use crate::types::{BridgeStatus, BitFlowError};

/// Mock implementation of AtomiqBridgeAdapter for testing purposes
/// This provides predictable behavior for unit tests and integration tests
#[starknet::contract]
pub mod MockAtomiqBridgeAdapter {
    use super::*;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };

    #[storage]
    struct Storage {
        // Mock configuration
        should_fail_lock: bool,
        should_fail_unlock: bool,
        should_fail_verification: bool,
        mock_bridge_time: u64,
        mock_exchange_rate: u256,
        mock_minimum_amount: u256,
        mock_fee_rate: u256,
        
        // Simplified tracking
        bridge_transactions: Map<u256, MockBridgeTransaction>,
        next_bridge_tx_id: u256,
        wrapped_bitcoin_balances: Map<ContractAddress, u256>,
        total_locked_bitcoin: u256,
        is_paused: bool,
        
        // Test helpers
        last_lock_amount: u256,
        last_unlock_amount: u256,
        lock_call_count: u256,
        unlock_call_count: u256,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct MockBridgeTransaction {
        id: u256,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
        status: BridgeStatus,
        created_at: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MockBitcoinLocked: MockBitcoinLocked,
        MockBitcoinUnlocked: MockBitcoinUnlocked,
        MockConfigUpdated: MockConfigUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MockBitcoinLocked {
        pub bridge_tx_id: u256,
        pub amount: u256,
        pub recipient: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MockBitcoinUnlocked {
        pub bridge_tx_id: u256,
        pub amount: u256,
        pub stream_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MockConfigUpdated {
        pub config_type: felt252,
        pub new_value: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Initialize with reasonable defaults for testing
        self.mock_exchange_rate.write(1000000); // 1:1 with 6 decimal precision
        self.mock_minimum_amount.write(10000); // 0.0001 BTC
        self.mock_fee_rate.write(100); // 1% in basis points
        self.mock_bridge_time.write(600); // 10 minutes default
        self.next_bridge_tx_id.write(1);
        self.is_paused.write(false);
        
        // Initialize failure flags to false (success by default)
        self.should_fail_lock.write(false);
        self.should_fail_unlock.write(false);
        self.should_fail_verification.write(false);
    }

    #[abi(embed_v0)]
    impl MockAtomiqBridgeAdapterImpl of IAtomiqBridgeAdapter<ContractState> {
        fn lock_bitcoin(
            ref self: ContractState,
            amount: u256,
            recipient: ContractAddress,
            bitcoin_tx_hash: felt252
        ) -> u256 {
            // Check if mock should fail
            if self.should_fail_lock.read() {
                panic!("Mock lock failure");
            }
            
            // Check if paused
            if self.is_paused.read() {
                panic!("Bridge is paused");
            }
            
            // Check minimum amount
            if amount < self.mock_minimum_amount.read() {
                panic!("Amount below minimum");
            }
            
            let bridge_tx_id = self.next_bridge_tx_id.read();
            let caller = get_caller_address();
            
            // Create mock transaction
            let mock_tx = MockBridgeTransaction {
                id: bridge_tx_id,
                sender: caller,
                recipient,
                amount,
                status: BridgeStatus::Confirmed, // Mock confirms immediately
                created_at: get_block_timestamp(),
            };
            
            self.bridge_transactions.entry(bridge_tx_id).write(mock_tx);
            self.next_bridge_tx_id.write(bridge_tx_id + 1);
            
            // Calculate wrapped Bitcoin (subtract mock fee)
            let fee = self._calculate_mock_fee(amount);
            let wrapped_amount = amount - fee;
            
            // Update balances
            let current_balance = self.wrapped_bitcoin_balances.entry(recipient).read();
            self.wrapped_bitcoin_balances.entry(recipient).write(current_balance + wrapped_amount);
            
            let total_locked = self.total_locked_bitcoin.read();
            self.total_locked_bitcoin.write(total_locked + amount);
            
            // Update test tracking
            self.last_lock_amount.write(amount);
            let call_count = self.lock_call_count.read();
            self.lock_call_count.write(call_count + 1);
            
            // Emit event
            self.emit(MockBitcoinLocked {
                bridge_tx_id,
                amount,
                recipient,
            });
            
            bridge_tx_id
        }

        fn unlock_bitcoin(
            ref self: ContractState,
            stream_id: u256,
            amount: u256,
            bitcoin_address: felt252
        ) -> bool {
            // Check if mock should fail
            if self.should_fail_unlock.read() {
                return false;
            }
            
            // Check if paused
            if self.is_paused.read() {
                return false;
            }
            
            let caller = get_caller_address();
            let current_balance = self.wrapped_bitcoin_balances.entry(caller).read();
            
            // Check sufficient balance
            if current_balance < amount {
                return false;
            }
            
            let bridge_tx_id = self.next_bridge_tx_id.read();
            
            // Create mock unlock transaction
            let mock_tx = MockBridgeTransaction {
                id: bridge_tx_id,
                sender: caller,
                recipient: caller,
                amount,
                status: BridgeStatus::Confirmed, // Mock confirms immediately
                created_at: get_block_timestamp(),
            };
            
            self.bridge_transactions.entry(bridge_tx_id).write(mock_tx);
            self.next_bridge_tx_id.write(bridge_tx_id + 1);
            
            // Update balances
            self.wrapped_bitcoin_balances.entry(caller).write(current_balance - amount);
            
            let total_locked = self.total_locked_bitcoin.read();
            self.total_locked_bitcoin.write(total_locked - amount);
            
            // Update test tracking
            self.last_unlock_amount.write(amount);
            let call_count = self.unlock_call_count.read();
            self.unlock_call_count.write(call_count + 1);
            
            // Emit event
            self.emit(MockBitcoinUnlocked {
                bridge_tx_id,
                amount,
                stream_id,
            });
            
            true
        }

        fn get_bridge_status(self: @ContractState, bridge_tx_id: u256) -> BridgeStatus {
            let mock_tx = self.bridge_transactions.entry(bridge_tx_id).read();
            mock_tx.status
        }

        fn verify_bitcoin_transaction(
            self: @ContractState,
            bitcoin_tx_hash: felt252,
            expected_amount: u256,
            expected_recipient: ContractAddress
        ) -> bool {
            // Check if mock should fail verification
            if self.should_fail_verification.read() {
                return false;
            }
            
            // Mock verification logic - return true for non-zero hashes
            bitcoin_tx_hash != 0
        }

        fn get_exchange_rate(self: @ContractState) -> u256 {
            self.mock_exchange_rate.read()
        }

        fn get_minimum_bridge_amount(self: @ContractState) -> u256 {
            self.mock_minimum_amount.read()
        }

        fn get_bridge_fee(self: @ContractState, amount: u256) -> u256 {
            self._calculate_mock_fee(amount)
        }

        fn estimate_bridge_time(self: @ContractState, amount: u256) -> u64 {
            self.mock_bridge_time.read()
        }

        fn get_total_locked_bitcoin(self: @ContractState) -> u256 {
            self.total_locked_bitcoin.read()
        }

        fn get_wrapped_bitcoin_balance(self: @ContractState, address: ContractAddress) -> u256 {
            self.wrapped_bitcoin_balances.entry(address).read()
        }

        fn pause_bridge(ref self: ContractState) -> bool {
            self.is_paused.write(true);
            true
        }

        fn resume_bridge(ref self: ContractState) -> bool {
            self.is_paused.write(false);
            true
        }

        fn process_bitcoin_to_wbtc_conversion(
            ref self: ContractState,
            bridge_tx_id: u256,
            bitcoin_confirmations: u8
        ) -> bool {
            // Mock always succeeds unless configured to fail
            if self.should_fail_verification.read() {
                return false;
            }
            
            // Update transaction status to confirmed
            self.simulate_status_change(bridge_tx_id, BridgeStatus::Confirmed);
            true
        }

        fn process_wbtc_to_bitcoin_conversion(
            ref self: ContractState,
            bridge_tx_id: u256,
            bitcoin_tx_hash: felt252
        ) -> bool {
            // Mock always succeeds unless configured to fail
            if self.should_fail_verification.read() {
                return false;
            }
            
            // Update transaction status to confirmed
            self.simulate_status_change(bridge_tx_id, BridgeStatus::Confirmed);
            true
        }

        fn handle_bridge_failure(
            ref self: ContractState,
            bridge_tx_id: u256,
            failure_reason: felt252
        ) -> bool {
            // Update transaction status to failed
            self.simulate_status_change(bridge_tx_id, BridgeStatus::Failed);
            
            // Mock refund logic - restore balances
            let mock_tx = self.bridge_transactions.entry(bridge_tx_id).read();
            if mock_tx.id != 0 {
                // Restore wrapped Bitcoin balance for the sender
                let current_balance = self.wrapped_bitcoin_balances.entry(mock_tx.sender).read();
                self.wrapped_bitcoin_balances.entry(mock_tx.sender).write(current_balance + mock_tx.amount);
            }
            
            true
        }

        fn retry_bridge_transaction(ref self: ContractState, bridge_tx_id: u256) -> bool {
            // Reset transaction to pending status
            self.simulate_status_change(bridge_tx_id, BridgeStatus::Pending);
            true
        }

        fn cancel_timed_out_transaction(ref self: ContractState, bridge_tx_id: u256) -> bool {
            // Update transaction status to cancelled
            self.simulate_status_change(bridge_tx_id, BridgeStatus::Cancelled);
            
            // Handle refund similar to failure
            self.handle_bridge_failure(bridge_tx_id, 'timeout');
            true
        }
    }

    #[generate_trait]
    impl MockInternalImpl of MockInternalTrait {
        fn _calculate_mock_fee(self: @ContractState, amount: u256) -> u256 {
            let fee_rate = self.mock_fee_rate.read();
            (amount * fee_rate) / 10000
        }
    }

    // Additional mock-specific functions for testing
    #[abi(embed_v0)]
    impl MockTestHelpersImpl of MockTestHelpers<ContractState> {
        /// Set whether lock operations should fail
        fn set_should_fail_lock(ref self: ContractState, should_fail: bool) {
            self.should_fail_lock.write(should_fail);
        }

        /// Set whether unlock operations should fail
        fn set_should_fail_unlock(ref self: ContractState, should_fail: bool) {
            self.should_fail_unlock.write(should_fail);
        }

        /// Set whether verification should fail
        fn set_should_fail_verification(ref self: ContractState, should_fail: bool) {
            self.should_fail_verification.write(should_fail);
        }

        /// Set mock bridge time
        fn set_mock_bridge_time(ref self: ContractState, time: u64) {
            self.mock_bridge_time.write(time);
            self.emit(MockConfigUpdated {
                config_type: 'bridge_time',
                new_value: time.into(),
            });
        }

        /// Set mock exchange rate
        fn set_mock_exchange_rate(ref self: ContractState, rate: u256) {
            self.mock_exchange_rate.write(rate);
            self.emit(MockConfigUpdated {
                config_type: 'exchange_rate',
                new_value: rate,
            });
        }

        /// Set mock minimum amount
        fn set_mock_minimum_amount(ref self: ContractState, amount: u256) {
            self.mock_minimum_amount.write(amount);
            self.emit(MockConfigUpdated {
                config_type: 'minimum_amount',
                new_value: amount,
            });
        }

        /// Set mock fee rate
        fn set_mock_fee_rate(ref self: ContractState, rate: u256) {
            self.mock_fee_rate.write(rate);
            self.emit(MockConfigUpdated {
                config_type: 'fee_rate',
                new_value: rate,
            });
        }

        /// Get the last lock amount for testing
        fn get_last_lock_amount(self: @ContractState) -> u256 {
            self.last_lock_amount.read()
        }

        /// Get the last unlock amount for testing
        fn get_last_unlock_amount(self: @ContractState) -> u256 {
            self.last_unlock_amount.read()
        }

        /// Get the number of lock calls made
        fn get_lock_call_count(self: @ContractState) -> u256 {
            self.lock_call_count.read()
        }

        /// Get the number of unlock calls made
        fn get_unlock_call_count(self: @ContractState) -> u256 {
            self.unlock_call_count.read()
        }

        /// Reset all counters and tracking
        fn reset_mock_state(ref self: ContractState) {
            self.last_lock_amount.write(0);
            self.last_unlock_amount.write(0);
            self.lock_call_count.write(0);
            self.unlock_call_count.write(0);
            self.should_fail_lock.write(false);
            self.should_fail_unlock.write(false);
            self.should_fail_verification.write(false);
        }

        /// Simulate a bridge transaction status change
        fn simulate_status_change(ref self: ContractState, bridge_tx_id: u256, new_status: BridgeStatus) {
            let mut mock_tx = self.bridge_transactions.entry(bridge_tx_id).read();
            mock_tx.status = new_status;
            self.bridge_transactions.entry(bridge_tx_id).write(mock_tx);
        }

        /// Add wrapped Bitcoin balance directly (for testing)
        fn add_wrapped_bitcoin_balance(ref self: ContractState, address: ContractAddress, amount: u256) {
            let current_balance = self.wrapped_bitcoin_balances.entry(address).read();
            self.wrapped_bitcoin_balances.entry(address).write(current_balance + amount);
        }
    }

    #[starknet::interface]
    trait MockTestHelpers<TContractState> {
        fn set_should_fail_lock(ref self: TContractState, should_fail: bool);
        fn set_should_fail_unlock(ref self: TContractState, should_fail: bool);
        fn set_should_fail_verification(ref self: TContractState, should_fail: bool);
        fn set_mock_bridge_time(ref self: TContractState, time: u64);
        fn set_mock_exchange_rate(ref self: TContractState, rate: u256);
        fn set_mock_minimum_amount(ref self: TContractState, amount: u256);
        fn set_mock_fee_rate(ref self: TContractState, rate: u256);
        fn get_last_lock_amount(self: @TContractState) -> u256;
        fn get_last_unlock_amount(self: @TContractState) -> u256;
        fn get_lock_call_count(self: @TContractState) -> u256;
        fn get_unlock_call_count(self: @TContractState) -> u256;
        fn reset_mock_state(ref self: TContractState);
        fn simulate_status_change(ref self: TContractState, bridge_tx_id: u256, new_status: BridgeStatus);
        fn add_wrapped_bitcoin_balance(ref self: TContractState, address: ContractAddress, amount: u256);
    }
}