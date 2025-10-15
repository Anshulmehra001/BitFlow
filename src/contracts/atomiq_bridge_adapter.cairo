use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use crate::interfaces::bridge_adapter::IAtomiqBridgeAdapter;
use crate::types::{BridgeStatus, BitFlowError};

#[starknet::contract]
pub mod AtomiqBridgeAdapter {
    use super::*;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };

    #[storage]
    struct Storage {
        // Bridge transaction tracking
        bridge_transactions: Map<u256, BridgeTransaction>,
        next_bridge_tx_id: u256,
        
        // Bitcoin transaction verification
        verified_bitcoin_txs: Map<felt252, bool>,
        
        // Bridge configuration
        exchange_rate: u256, // 1:1 ratio with fees
        minimum_bridge_amount: u256, // Minimum satoshis
        bridge_fee_rate: u256, // Fee rate in basis points (100 = 1%)
        
        // Bridge state
        is_paused: bool,
        total_locked_bitcoin: u256,
        
        // Wrapped Bitcoin balances
        wrapped_bitcoin_balances: Map<ContractAddress, u256>,
        
        // Access control
        owner: ContractAddress,
        authorized_contracts: Map<ContractAddress, bool>,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct BridgeTransaction {
        id: u256,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
        bitcoin_tx_hash: felt252,
        status: BridgeStatus,
        created_at: u64,
        confirmed_at: u64,
        bitcoin_address: felt252, // For unlock operations
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        BitcoinLocked: BitcoinLocked,
        BitcoinUnlocked: BitcoinUnlocked,
        BridgeStatusUpdated: BridgeStatusUpdated,
        BridgePaused: BridgePaused,
        BridgeResumed: BridgeResumed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BitcoinLocked {
        pub bridge_tx_id: u256,
        pub sender: ContractAddress,
        pub recipient: ContractAddress,
        pub amount: u256,
        pub bitcoin_tx_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BitcoinUnlocked {
        pub bridge_tx_id: u256,
        pub stream_id: u256,
        pub amount: u256,
        pub bitcoin_address: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BridgeStatusUpdated {
        pub bridge_tx_id: u256,
        pub old_status: BridgeStatus,
        pub new_status: BridgeStatus,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BridgePaused {
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BridgeResumed {
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        initial_exchange_rate: u256,
        minimum_amount: u256,
        fee_rate: u256
    ) {
        self.owner.write(owner);
        self.exchange_rate.write(initial_exchange_rate);
        self.minimum_bridge_amount.write(minimum_amount);
        self.bridge_fee_rate.write(fee_rate);
        self.next_bridge_tx_id.write(1);
        self.is_paused.write(false);
        self.total_locked_bitcoin.write(0);
    }

    #[abi(embed_v0)]
    impl AtomiqBridgeAdapterImpl of IAtomiqBridgeAdapter<ContractState> {
        fn lock_bitcoin(
            ref self: ContractState,
            amount: u256,
            recipient: ContractAddress,
            bitcoin_tx_hash: felt252
        ) -> u256 {
            self._assert_not_paused();
            self._assert_minimum_amount(amount);
            
            let caller = get_caller_address();
            let bridge_tx_id = self.next_bridge_tx_id.read();
            
            // Verify Bitcoin transaction hasn't been used before
            assert(!self.verified_bitcoin_txs.entry(bitcoin_tx_hash).read(), 'Bitcoin tx already used');
            
            // Create bridge transaction record
            let bridge_tx = BridgeTransaction {
                id: bridge_tx_id,
                sender: caller,
                recipient,
                amount,
                bitcoin_tx_hash,
                status: BridgeStatus::Pending,
                created_at: get_block_timestamp(),
                confirmed_at: 0,
                bitcoin_address: 0, // Not used for lock operations
            };
            
            self.bridge_transactions.entry(bridge_tx_id).write(bridge_tx);
            self.verified_bitcoin_txs.entry(bitcoin_tx_hash).write(true);
            self.next_bridge_tx_id.write(bridge_tx_id + 1);
            
            // Calculate wrapped Bitcoin amount (subtract fees)
            let fee = self._calculate_bridge_fee(amount);
            let wrapped_amount = amount - fee;
            
            // Mint wrapped Bitcoin to recipient
            let current_balance = self.wrapped_bitcoin_balances.entry(recipient).read();
            self.wrapped_bitcoin_balances.entry(recipient).write(current_balance + wrapped_amount);
            
            // Update total locked Bitcoin
            let total_locked = self.total_locked_bitcoin.read();
            self.total_locked_bitcoin.write(total_locked + amount);
            
            // Emit event
            self.emit(BitcoinLocked {
                bridge_tx_id,
                sender: caller,
                recipient,
                amount,
                bitcoin_tx_hash,
            });
            
            bridge_tx_id
        }

        fn unlock_bitcoin(
            ref self: ContractState,
            stream_id: u256,
            amount: u256,
            bitcoin_address: felt252
        ) -> bool {
            self._assert_not_paused();
            self._assert_authorized_contract();
            
            let caller = get_caller_address();
            
            // Check wrapped Bitcoin balance
            let current_balance = self.wrapped_bitcoin_balances.entry(caller).read();
            assert(current_balance >= amount, 'Insufficient wrapped Bitcoin');
            
            let bridge_tx_id = self.next_bridge_tx_id.read();
            
            // Create unlock transaction record
            let bridge_tx = BridgeTransaction {
                id: bridge_tx_id,
                sender: caller,
                recipient: caller, // Same for unlock
                amount,
                bitcoin_tx_hash: 0, // Will be set when Bitcoin tx is created
                status: BridgeStatus::Pending,
                created_at: get_block_timestamp(),
                confirmed_at: 0,
                bitcoin_address,
            };
            
            self.bridge_transactions.entry(bridge_tx_id).write(bridge_tx);
            self.next_bridge_tx_id.write(bridge_tx_id + 1);
            
            // Burn wrapped Bitcoin
            self.wrapped_bitcoin_balances.entry(caller).write(current_balance - amount);
            
            // Update total locked Bitcoin
            let total_locked = self.total_locked_bitcoin.read();
            self.total_locked_bitcoin.write(total_locked - amount);
            
            // Emit event
            self.emit(BitcoinUnlocked {
                bridge_tx_id,
                stream_id,
                amount,
                bitcoin_address,
            });
            
            true
        }

        fn get_bridge_status(self: @ContractState, bridge_tx_id: u256) -> BridgeStatus {
            let bridge_tx = self.bridge_transactions.entry(bridge_tx_id).read();
            bridge_tx.status
        }

        fn verify_bitcoin_transaction(
            self: @ContractState,
            bitcoin_tx_hash: felt252,
            expected_amount: u256,
            expected_recipient: ContractAddress
        ) -> bool {
            // In a real implementation, this would verify the Bitcoin transaction
            // For now, we'll implement basic validation logic
            
            // Check if transaction hash has been used
            if self.verified_bitcoin_txs.entry(bitcoin_tx_hash).read() {
                return false;
            }
            
            // In production, this would:
            // 1. Query Bitcoin network for transaction details
            // 2. Verify transaction amount matches expected_amount
            // 3. Verify transaction sends to correct bridge address
            // 4. Check transaction has sufficient confirmations
            
            // For testing purposes, we'll return true for non-zero hashes
            bitcoin_tx_hash != 0
        }

        fn get_exchange_rate(self: @ContractState) -> u256 {
            self.exchange_rate.read()
        }

        fn get_minimum_bridge_amount(self: @ContractState) -> u256 {
            self.minimum_bridge_amount.read()
        }

        fn get_bridge_fee(self: @ContractState, amount: u256) -> u256 {
            self._calculate_bridge_fee(amount)
        }

        fn estimate_bridge_time(self: @ContractState, amount: u256) -> u64 {
            // Estimate based on amount and current network conditions
            // Larger amounts typically require more confirmations
            if amount > 100000000 { // > 1 BTC
                3600 // 1 hour
            } else if amount > 10000000 { // > 0.1 BTC
                1800 // 30 minutes
            } else {
                600 // 10 minutes
            }
        }

        fn get_total_locked_bitcoin(self: @ContractState) -> u256 {
            self.total_locked_bitcoin.read()
        }

        fn get_wrapped_bitcoin_balance(self: @ContractState, address: ContractAddress) -> u256 {
            self.wrapped_bitcoin_balances.entry(address).read()
        }

        fn pause_bridge(ref self: ContractState) -> bool {
            self._assert_owner();
            self.is_paused.write(true);
            
            self.emit(BridgePaused {
                timestamp: get_block_timestamp(),
            });
            
            true
        }

        fn resume_bridge(ref self: ContractState) -> bool {
            self._assert_owner();
            self.is_paused.write(false);
            
            self.emit(BridgeResumed {
                timestamp: get_block_timestamp(),
            });
            
            true
        }

        fn process_bitcoin_to_wbtc_conversion(
            ref self: ContractState,
            bridge_tx_id: u256,
            bitcoin_confirmations: u8
        ) -> bool {
            self._assert_authorized_contract();
            self.process_bitcoin_to_wbtc_conversion(bridge_tx_id, bitcoin_confirmations)
        }

        fn process_wbtc_to_bitcoin_conversion(
            ref self: ContractState,
            bridge_tx_id: u256,
            bitcoin_tx_hash: felt252
        ) -> bool {
            self._assert_authorized_contract();
            self.process_wbtc_to_bitcoin_conversion(bridge_tx_id, bitcoin_tx_hash)
        }

        fn handle_bridge_failure(
            ref self: ContractState,
            bridge_tx_id: u256,
            failure_reason: felt252
        ) -> bool {
            self._assert_authorized_contract();
            self.handle_bridge_failure(bridge_tx_id, failure_reason)
        }

        fn retry_bridge_transaction(ref self: ContractState, bridge_tx_id: u256) -> bool {
            self.retry_bridge_transaction(bridge_tx_id)
        }

        fn cancel_timed_out_transaction(ref self: ContractState, bridge_tx_id: u256) -> bool {
            self.cancel_timed_out_transaction(bridge_tx_id)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_not_paused(self: @ContractState) {
            assert(!self.is_paused.read(), 'Bridge is paused');
        }

        fn _assert_owner(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can call');
        }

        fn _assert_authorized_contract(self: @ContractState) {
            let caller = get_caller_address();
            assert(
                caller == self.owner.read() || self.authorized_contracts.entry(caller).read(),
                'Unauthorized contract'
            );
        }

        fn _assert_minimum_amount(self: @ContractState, amount: u256) {
            assert(amount >= self.minimum_bridge_amount.read(), 'Amount below minimum');
        }

        fn _calculate_bridge_fee(self: @ContractState, amount: u256) -> u256 {
            let fee_rate = self.bridge_fee_rate.read();
            (amount * fee_rate) / 10000 // Fee rate in basis points
        }

        fn update_bridge_status(
            ref self: ContractState,
            bridge_tx_id: u256,
            new_status: BridgeStatus
        ) {
            let mut bridge_tx = self.bridge_transactions.entry(bridge_tx_id).read();
            let old_status = bridge_tx.status;
            bridge_tx.status = new_status;
            
            if matches!(new_status, BridgeStatus::Confirmed) {
                bridge_tx.confirmed_at = get_block_timestamp();
            }
            
            self.bridge_transactions.entry(bridge_tx_id).write(bridge_tx);
            
            self.emit(BridgeStatusUpdated {
                bridge_tx_id,
                old_status,
                new_status,
            });
        }

        fn authorize_contract(ref self: ContractState, contract: ContractAddress) {
            self._assert_owner();
            self.authorized_contracts.entry(contract).write(true);
        }

        fn revoke_contract_authorization(ref self: ContractState, contract: ContractAddress) {
            self._assert_owner();
            self.authorized_contracts.entry(contract).write(false);
        }

        /// Process Bitcoin to wBTC conversion with confirmation waiting
        fn process_bitcoin_to_wbtc_conversion(
            ref self: ContractState,
            bridge_tx_id: u256,
            bitcoin_confirmations: u8
        ) -> bool {
            let mut bridge_tx = self.bridge_transactions.entry(bridge_tx_id).read();
            
            // Ensure transaction exists and is in pending state
            assert(bridge_tx.id != 0, 'Bridge transaction not found');
            assert(matches!(bridge_tx.status, BridgeStatus::Pending), 'Transaction not pending');
            
            // Check if we have sufficient confirmations
            let required_confirmations = self._get_required_confirmations(bridge_tx.amount);
            
            if bitcoin_confirmations >= required_confirmations {
                // Update status to confirmed
                bridge_tx.status = BridgeStatus::Confirmed;
                bridge_tx.confirmed_at = get_block_timestamp();
                self.bridge_transactions.entry(bridge_tx_id).write(bridge_tx);
                
                self.emit(BridgeStatusUpdated {
                    bridge_tx_id,
                    old_status: BridgeStatus::Pending,
                    new_status: BridgeStatus::Confirmed,
                });
                
                true
            } else {
                // Still waiting for confirmations
                false
            }
        }

        /// Process wBTC to Bitcoin conversion
        fn process_wbtc_to_bitcoin_conversion(
            ref self: ContractState,
            bridge_tx_id: u256,
            bitcoin_tx_hash: felt252
        ) -> bool {
            let mut bridge_tx = self.bridge_transactions.entry(bridge_tx_id).read();
            
            // Ensure transaction exists and is in pending state
            assert(bridge_tx.id != 0, 'Bridge transaction not found');
            assert(matches!(bridge_tx.status, BridgeStatus::Pending), 'Transaction not pending');
            
            // Update with Bitcoin transaction hash
            bridge_tx.bitcoin_tx_hash = bitcoin_tx_hash;
            bridge_tx.status = BridgeStatus::Confirmed;
            bridge_tx.confirmed_at = get_block_timestamp();
            self.bridge_transactions.entry(bridge_tx_id).write(bridge_tx);
            
            self.emit(BridgeStatusUpdated {
                bridge_tx_id,
                old_status: BridgeStatus::Pending,
                new_status: BridgeStatus::Confirmed,
            });
            
            true
        }

        /// Handle bridge transaction failure
        fn handle_bridge_failure(
            ref self: ContractState,
            bridge_tx_id: u256,
            failure_reason: felt252
        ) -> bool {
            let mut bridge_tx = self.bridge_transactions.entry(bridge_tx_id).read();
            
            // Ensure transaction exists
            assert(bridge_tx.id != 0, 'Bridge transaction not found');
            
            // Only allow failure handling for pending transactions
            if !matches!(bridge_tx.status, BridgeStatus::Pending) {
                return false;
            }
            
            // Update status to failed
            bridge_tx.status = BridgeStatus::Failed;
            self.bridge_transactions.entry(bridge_tx_id).write(bridge_tx);
            
            // Handle refund logic based on transaction type
            if bridge_tx.bitcoin_address == 0 {
                // This was a lock operation - refund wrapped Bitcoin
                let current_balance = self.wrapped_bitcoin_balances.entry(bridge_tx.recipient).read();
                let fee = self._calculate_bridge_fee(bridge_tx.amount);
                let wrapped_amount = bridge_tx.amount - fee;
                
                // Remove the wrapped Bitcoin that was minted
                if current_balance >= wrapped_amount {
                    self.wrapped_bitcoin_balances.entry(bridge_tx.recipient).write(current_balance - wrapped_amount);
                }
                
                // Reduce total locked Bitcoin
                let total_locked = self.total_locked_bitcoin.read();
                if total_locked >= bridge_tx.amount {
                    self.total_locked_bitcoin.write(total_locked - bridge_tx.amount);
                }
            } else {
                // This was an unlock operation - restore wrapped Bitcoin
                let current_balance = self.wrapped_bitcoin_balances.entry(bridge_tx.sender).read();
                self.wrapped_bitcoin_balances.entry(bridge_tx.sender).write(current_balance + bridge_tx.amount);
                
                // Restore total locked Bitcoin
                let total_locked = self.total_locked_bitcoin.read();
                self.total_locked_bitcoin.write(total_locked + bridge_tx.amount);
            }
            
            self.emit(BridgeStatusUpdated {
                bridge_tx_id,
                old_status: BridgeStatus::Pending,
                new_status: BridgeStatus::Failed,
            });
            
            true
        }

        /// Retry a failed bridge transaction
        fn retry_bridge_transaction(ref self: ContractState, bridge_tx_id: u256) -> bool {
            self._assert_owner();
            
            let mut bridge_tx = self.bridge_transactions.entry(bridge_tx_id).read();
            
            // Ensure transaction exists and is failed
            assert(bridge_tx.id != 0, 'Bridge transaction not found');
            assert(matches!(bridge_tx.status, BridgeStatus::Failed), 'Transaction not failed');
            
            // Reset to pending status
            bridge_tx.status = BridgeStatus::Pending;
            bridge_tx.confirmed_at = 0;
            self.bridge_transactions.entry(bridge_tx_id).write(bridge_tx);
            
            self.emit(BridgeStatusUpdated {
                bridge_tx_id,
                old_status: BridgeStatus::Failed,
                new_status: BridgeStatus::Pending,
            });
            
            true
        }

        /// Get required confirmations based on amount
        fn _get_required_confirmations(self: @ContractState, amount: u256) -> u8 {
            // More confirmations required for larger amounts
            if amount >= 100000000 { // >= 1 BTC
                6
            } else if amount >= 10000000 { // >= 0.1 BTC
                3
            } else {
                1
            }
        }

        /// Check if bridge transaction has timed out
        fn _is_transaction_timed_out(self: @ContractState, bridge_tx_id: u256) -> bool {
            let bridge_tx = self.bridge_transactions.entry(bridge_tx_id).read();
            let current_time = get_block_timestamp();
            let timeout_duration = 3600; // 1 hour timeout
            
            matches!(bridge_tx.status, BridgeStatus::Pending) && 
            (current_time - bridge_tx.created_at) > timeout_duration
        }

        /// Cancel a timed out transaction
        fn cancel_timed_out_transaction(ref self: ContractState, bridge_tx_id: u256) -> bool {
            assert(self._is_transaction_timed_out(bridge_tx_id), 'Transaction not timed out');
            
            let mut bridge_tx = self.bridge_transactions.entry(bridge_tx_id).read();
            bridge_tx.status = BridgeStatus::Cancelled;
            self.bridge_transactions.entry(bridge_tx_id).write(bridge_tx);
            
            // Handle refund similar to failure case
            self.handle_bridge_failure(bridge_tx_id, 'timeout');
            
            self.emit(BridgeStatusUpdated {
                bridge_tx_id,
                old_status: BridgeStatus::Pending,
                new_status: BridgeStatus::Cancelled,
            });
            
            true
        }
    }
}