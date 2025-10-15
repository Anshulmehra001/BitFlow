#[starknet::contract]
pub mod YieldManager {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };
    use core::zeroable::Zeroable;
    use crate::interfaces::yield_manager::IYieldManager;
    use crate::interfaces::defi_protocol::{IDeFiProtocolDispatcher, IDeFiProtocolDispatcherTrait};
    use crate::types::{YieldPosition, BitFlowError};
    use crate::utils::validation::Validation;
    use crate::utils::math;

    #[storage]
    struct Storage {
        // Mapping from stream_id to YieldPosition
        yield_positions: Map<u256, YieldPosition>,
        // Mapping from protocol address to yield rate (in basis points)
        protocol_rates: Map<ContractAddress, u256>,
        // Mapping from protocol address to minimum stake amount
        protocol_min_stakes: Map<ContractAddress, u256>,
        // Array of supported protocols
        supported_protocols: Map<u32, ContractAddress>,
        protocol_count: u32,
        // Mapping from protocol to adapter contract address
        protocol_adapters: Map<ContractAddress, ContractAddress>,
        // Default token for yield operations (wBTC)
        default_token: ContractAddress,
        // Auto-strategy selection enabled
        auto_strategy_enabled: bool,
        // Owner of the contract
        owner: ContractAddress,
        // Emergency pause state
        is_paused: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        FundsStaked: FundsStaked,
        FundsUnstaked: FundsUnstaked,
        YieldDistributed: YieldDistributed,
        YieldClaimed: YieldClaimed,
        YieldEnabled: YieldEnabled,
        YieldDisabled: YieldDisabled,
        ProtocolAdded: ProtocolAdded,
        EmergencyPause: EmergencyPause,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundsStaked {
        pub stream_id: u256,
        pub protocol: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundsUnstaked {
        pub stream_id: u256,
        pub protocol: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct YieldDistributed {
        pub stream_id: u256,
        pub yield_amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct YieldClaimed {
        pub stream_id: u256,
        pub claimed_amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct YieldEnabled {
        pub stream_id: u256,
        pub protocol: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct YieldDisabled {
        pub stream_id: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProtocolAdded {
        pub protocol: ContractAddress,
        pub min_stake_amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EmergencyPause {
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, default_token: ContractAddress) {
        self.owner.write(owner);
        self.is_paused.write(false);
        self.protocol_count.write(0);
        self.default_token.write(default_token);
        self.auto_strategy_enabled.write(true);
    }

    #[abi(embed_v0)]
    impl YieldManagerImpl of IYieldManager<ContractState> {
        fn stake_idle_funds(
            ref self: ContractState,
            stream_id: u256,
            amount: u256,
            protocol: ContractAddress
        ) -> bool {
            self._assert_not_paused();
            self._assert_valid_amount(amount);
            self._assert_supported_protocol(protocol);

            let min_stake = self.protocol_min_stakes.entry(protocol).read();
            assert(amount >= min_stake, 'Amount below minimum stake');

            let current_time = get_block_timestamp();
            let mut position = self.yield_positions.entry(stream_id).read();

            // Get the protocol adapter and deposit funds
            let adapter_address = self.protocol_adapters.entry(protocol).read();
            assert(!adapter_address.is_zero(), 'No adapter for protocol');
            
            let adapter = IDeFiProtocolDispatcher { contract_address: adapter_address };
            let token = self.default_token.read();
            
            let deposit_success = adapter.deposit(token, amount);
            assert(deposit_success, 'Failed to deposit to protocol');

            // If position doesn't exist, create new one
            if position.stream_id == 0 {
                position = YieldPosition {
                    stream_id,
                    protocol,
                    staked_amount: amount,
                    earned_yield: 0,
                    last_update: current_time,
                };
            } else {
                // Update existing position
                self._update_yield_earnings(ref position, current_time);
                position.staked_amount += amount;
                position.protocol = protocol;
                position.last_update = current_time;
            }

            self.yield_positions.entry(stream_id).write(position);

            self.emit(FundsStaked {
                stream_id,
                protocol,
                amount,
                timestamp: current_time,
            });

            true
        }

        fn unstake_funds(ref self: ContractState, stream_id: u256, amount: u256) -> bool {
            self._assert_not_paused();
            self._assert_valid_amount(amount);

            let current_time = get_block_timestamp();
            let mut position = self.yield_positions.entry(stream_id).read();
            
            assert(position.stream_id != 0, 'No yield position found');
            assert(position.staked_amount >= amount, 'Insufficient staked amount');

            // Get the protocol adapter and withdraw funds
            let adapter_address = self.protocol_adapters.entry(position.protocol).read();
            assert(!adapter_address.is_zero(), 'No adapter for protocol');
            
            let adapter = IDeFiProtocolDispatcher { contract_address: adapter_address };
            let token = self.default_token.read();
            
            let withdraw_success = adapter.withdraw(token, amount);
            assert(withdraw_success, 'Failed to withdraw from protocol');

            // Update yield earnings before unstaking
            self._update_yield_earnings(ref position, current_time);
            
            position.staked_amount -= amount;
            position.last_update = current_time;

            self.yield_positions.entry(stream_id).write(position);

            self.emit(FundsUnstaked {
                stream_id,
                protocol: position.protocol,
                amount,
                timestamp: current_time,
            });

            true
        }

        fn distribute_yield(ref self: ContractState, stream_id: u256) -> u256 {
            self._assert_not_paused();

            let current_time = get_block_timestamp();
            let mut position = self.yield_positions.entry(stream_id).read();
            
            assert(position.stream_id != 0, 'No yield position found');

            // Update and calculate yield earnings
            self._update_yield_earnings(ref position, current_time);
            
            let yield_to_distribute = position.earned_yield;
            position.earned_yield = 0;
            position.last_update = current_time;

            self.yield_positions.entry(stream_id).write(position);

            if yield_to_distribute > 0 {
                self.emit(YieldDistributed {
                    stream_id,
                    yield_amount: yield_to_distribute,
                    timestamp: current_time,
                });
            }

            yield_to_distribute
        }

        fn claim_yield(ref self: ContractState, stream_id: u256) -> u256 {
            let yield_amount = self.distribute_yield(stream_id);
            
            if yield_amount > 0 {
                self.emit(YieldClaimed {
                    stream_id,
                    claimed_amount: yield_amount,
                    timestamp: get_block_timestamp(),
                });
            }

            yield_amount
        }

        fn get_yield_rate(self: @ContractState, protocol: ContractAddress) -> u256 {
            self.protocol_rates.entry(protocol).read()
        }

        fn get_yield_position(self: @ContractState, stream_id: u256) -> YieldPosition {
            self.yield_positions.entry(stream_id).read()
        }

        fn get_total_earned_yield(self: @ContractState, stream_id: u256) -> u256 {
            let position = self.yield_positions.entry(stream_id).read();
            if position.stream_id == 0 {
                return 0;
            }

            // Calculate current earnings including pending yield
            let current_time = get_block_timestamp();
            let time_elapsed = current_time - position.last_update;
            let yield_rate = self.protocol_rates.entry(position.protocol).read();
            
            let pending_yield = math::calculate_yield(
                position.staked_amount,
                yield_rate,
                time_elapsed.into()
            );

            position.earned_yield + pending_yield
        }

        fn enable_yield(
            ref self: ContractState,
            stream_id: u256,
            protocol: ContractAddress
        ) -> bool {
            self._assert_not_paused();
            self._assert_supported_protocol(protocol);

            let current_time = get_block_timestamp();
            let mut position = self.yield_positions.entry(stream_id).read();

            // Create new position if it doesn't exist
            if position.stream_id == 0 {
                position = YieldPosition {
                    stream_id,
                    protocol,
                    staked_amount: 0,
                    earned_yield: 0,
                    last_update: current_time,
                };
            } else {
                position.protocol = protocol;
                position.last_update = current_time;
            }

            self.yield_positions.entry(stream_id).write(position);

            self.emit(YieldEnabled {
                stream_id,
                protocol,
                timestamp: current_time,
            });

            true
        }

        fn disable_yield(ref self: ContractState, stream_id: u256) -> bool {
            self._assert_not_paused();

            let current_time = get_block_timestamp();
            let mut position = self.yield_positions.entry(stream_id).read();
            
            assert(position.stream_id != 0, 'No yield position found');

            // Update final yield earnings
            self._update_yield_earnings(ref position, current_time);
            
            // If there are staked funds, they need to be unstaked first
            assert(position.staked_amount == 0, 'Must unstake funds first');

            // Clear the position
            let empty_position = YieldPosition {
                stream_id: 0,
                protocol: Zeroable::zero(),
                staked_amount: 0,
                earned_yield: 0,
                last_update: 0,
            };
            
            self.yield_positions.entry(stream_id).write(empty_position);

            self.emit(YieldDisabled {
                stream_id,
                timestamp: current_time,
            });

            true
        }

        fn get_supported_protocols(self: @ContractState) -> Array<ContractAddress> {
            let mut protocols = ArrayTrait::new();
            let count = self.protocol_count.read();
            
            let mut i = 0;
            while i < count {
                let protocol = self.supported_protocols.entry(i).read();
                protocols.append(protocol);
                i += 1;
            };

            protocols
        }

        fn add_yield_protocol(
            ref self: ContractState,
            protocol: ContractAddress,
            min_stake_amount: u256
        ) -> bool {
            self._assert_owner();
            self._assert_valid_address(protocol);
            self._assert_valid_amount(min_stake_amount);

            let count = self.protocol_count.read();
            self.supported_protocols.entry(count).write(protocol);
            self.protocol_min_stakes.entry(protocol).write(min_stake_amount);
            self.protocol_count.write(count + 1);

            // Set default yield rate (can be updated later)
            self.protocol_rates.entry(protocol).write(500); // 5% APY in basis points

            self.emit(ProtocolAdded {
                protocol,
                min_stake_amount,
                timestamp: get_block_timestamp(),
            });

            true
        }

        fn select_optimal_yield_strategy(self: @ContractState, amount: u256) -> ContractAddress {
            let count = self.protocol_count.read();
            assert(count > 0, 'No protocols available');

            let mut best_protocol = self.supported_protocols.entry(0).read();
            let mut best_rate = 0;
            let token = self.default_token.read();

            // Get live rates from protocol adapters for better selection
            let mut i = 0;
            while i < count {
                let protocol = self.supported_protocols.entry(i).read();
                let min_stake = self.protocol_min_stakes.entry(protocol).read();
                
                // Only consider protocols where amount meets minimum stake
                if amount >= min_stake {
                    let adapter_address = self.protocol_adapters.entry(protocol).read();
                    let rate = if !adapter_address.is_zero() {
                        let adapter = IDeFiProtocolDispatcher { contract_address: adapter_address };
                        adapter.get_yield_rate(token)
                    } else {
                        self.protocol_rates.entry(protocol).read()
                    };
                    
                    if rate > best_rate {
                        best_protocol = protocol;
                        best_rate = rate;
                    }
                }
                i += 1;
            };

            best_protocol
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_not_paused(self: @ContractState) {
            assert(!self.is_paused.read(), 'Contract is paused');
        }

        fn _assert_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), 'Only owner allowed');
        }

        fn _assert_valid_amount(self: @ContractState, amount: u256) {
            assert(amount > 0, 'Amount must be positive');
        }

        fn _assert_valid_address(self: @ContractState, address: ContractAddress) {
            assert(!address.is_zero(), 'Invalid address');
        }

        fn _assert_supported_protocol(self: @ContractState, protocol: ContractAddress) {
            let count = self.protocol_count.read();
            let mut found = false;
            
            let mut i = 0;
            while i < count {
                if self.supported_protocols.entry(i).read() == protocol {
                    found = true;
                    break;
                }
                i += 1;
            };
            
            assert(found, 'Protocol not supported');
        }

        fn _update_yield_earnings(self: @ContractState, ref position: YieldPosition, current_time: u64) {
            if position.staked_amount == 0 {
                return;
            }

            let time_elapsed = current_time - position.last_update;
            if time_elapsed == 0 {
                return;
            }

            let yield_rate = self.protocol_rates.entry(position.protocol).read();
            let new_yield = math::calculate_yield(
                position.staked_amount,
                yield_rate,
                time_elapsed.into()
            );

            position.earned_yield += new_yield;
        }

        fn emergency_pause(ref self: ContractState) {
            self._assert_owner();
            self.is_paused.write(true);
            
            self.emit(EmergencyPause {
                timestamp: get_block_timestamp(),
            });
        }

        fn unpause(ref self: ContractState) {
            self._assert_owner();
            self.is_paused.write(false);
        }

        fn set_protocol_adapter(
            ref self: ContractState,
            protocol: ContractAddress,
            adapter: ContractAddress
        ) {
            self._assert_owner();
            self._assert_valid_address(protocol);
            self._assert_valid_address(adapter);
            self.protocol_adapters.entry(protocol).write(adapter);
        }

        fn get_protocol_adapter(self: @ContractState, protocol: ContractAddress) -> ContractAddress {
            self.protocol_adapters.entry(protocol).read()
        }

        fn set_auto_strategy_enabled(ref self: ContractState, enabled: bool) {
            self._assert_owner();
            self.auto_strategy_enabled.write(enabled);
        }

        fn is_auto_strategy_enabled(self: @ContractState) -> bool {
            self.auto_strategy_enabled.read()
        }

        fn update_protocol_rate(ref self: ContractState, protocol: ContractAddress, new_rate: u256) {
            self._assert_owner();
            self.protocol_rates.entry(protocol).write(new_rate);
        }
    }
}