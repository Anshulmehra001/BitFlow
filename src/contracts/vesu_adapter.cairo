#[starknet::contract]
pub mod VesuAdapter {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };
    use crate::interfaces::defi_protocol::{IDeFiProtocol, IVesuProtocol};
    use crate::types::BitFlowError;

    #[storage]
    struct Storage {
        // Vesu protocol contract address
        vesu_contract: ContractAddress,
        // Mapping from token to user balances
        user_balances: Map<(ContractAddress, ContractAddress), u256>,
        // Mapping from token to yield rates
        yield_rates: Map<ContractAddress, u256>,
        // Owner of the adapter
        owner: ContractAddress,
        // Emergency pause state
        is_paused: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Deposited: Deposited,
        Withdrawn: Withdrawn,
        YieldClaimed: YieldClaimed,
        RateUpdated: RateUpdated,
        EmergencyPause: EmergencyPause,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Deposited {
        pub user: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdrawn {
        pub user: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct YieldClaimed {
        pub user: ContractAddress,
        pub token: ContractAddress,
        pub yield_amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RateUpdated {
        pub token: ContractAddress,
        pub new_rate: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EmergencyPause {
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, vesu_contract: ContractAddress, owner: ContractAddress) {
        self.vesu_contract.write(vesu_contract);
        self.owner.write(owner);
        self.is_paused.write(false);
    }

    #[abi(embed_v0)]
    impl DeFiProtocolImpl of IDeFiProtocol<ContractState> {
        fn deposit(ref self: ContractState, token: ContractAddress, amount: u256) -> bool {
            self._assert_not_paused();
            self._assert_valid_amount(amount);
            
            let caller = get_caller_address();
            let contract_address = get_contract_address();
            
            // Call Vesu protocol to supply tokens
            let vesu_contract = self.vesu_contract.read();
            let vesu_dispatcher = IVesuProtocolDispatcher { contract_address: vesu_contract };
            
            let success = vesu_dispatcher.supply(token, amount, contract_address);
            
            if success {
                // Update user balance
                let current_balance = self.user_balances.entry((token, caller)).read();
                self.user_balances.entry((token, caller)).write(current_balance + amount);
                
                self.emit(Deposited {
                    user: caller,
                    token,
                    amount,
                    timestamp: starknet::get_block_timestamp(),
                });
            }
            
            success
        }

        fn withdraw(ref self: ContractState, token: ContractAddress, amount: u256) -> bool {
            self._assert_not_paused();
            self._assert_valid_amount(amount);
            
            let caller = get_caller_address();
            let current_balance = self.user_balances.entry((token, caller)).read();
            
            assert(current_balance >= amount, 'Insufficient balance');
            
            // Call Vesu protocol to withdraw tokens
            let vesu_contract = self.vesu_contract.read();
            let vesu_dispatcher = IVesuProtocolDispatcher { contract_address: vesu_contract };
            
            let withdrawn_amount = vesu_dispatcher.withdraw(token, amount, caller);
            
            if withdrawn_amount > 0 {
                // Update user balance
                self.user_balances.entry((token, caller)).write(current_balance - withdrawn_amount);
                
                self.emit(Withdrawn {
                    user: caller,
                    token,
                    amount: withdrawn_amount,
                    timestamp: starknet::get_block_timestamp(),
                });
                
                true
            } else {
                false
            }
        }

        fn get_balance(self: @ContractState, token: ContractAddress, user: ContractAddress) -> u256 {
            self.user_balances.entry((token, user)).read()
        }

        fn get_yield_rate(self: @ContractState, token: ContractAddress) -> u256 {
            // Try to get live rate from Vesu, fallback to cached rate
            let vesu_contract = self.vesu_contract.read();
            let vesu_dispatcher = IVesuProtocolDispatcher { contract_address: vesu_contract };
            
            let live_rate = vesu_dispatcher.get_supply_apy(token);
            if live_rate > 0 {
                live_rate
            } else {
                self.yield_rates.entry(token).read()
            }
        }

        fn claim_yield(ref self: ContractState, token: ContractAddress) -> u256 {
            self._assert_not_paused();
            
            let caller = get_caller_address();
            
            // For Vesu, yield is typically auto-compounded, so we calculate the difference
            let vesu_contract = self.vesu_contract.read();
            let vesu_dispatcher = IVesuProtocolDispatcher { contract_address: vesu_contract };
            
            let current_vesu_balance = vesu_dispatcher.get_supply_balance(token, get_contract_address());
            let recorded_balance = self.user_balances.entry((token, caller)).read();
            
            if current_vesu_balance > recorded_balance {
                let yield_earned = current_vesu_balance - recorded_balance;
                
                // Update recorded balance
                self.user_balances.entry((token, caller)).write(current_vesu_balance);
                
                self.emit(YieldClaimed {
                    user: caller,
                    token,
                    yield_amount: yield_earned,
                    timestamp: starknet::get_block_timestamp(),
                });
                
                yield_earned
            } else {
                0
            }
        }

        fn get_tvl(self: @ContractState, token: ContractAddress) -> u256 {
            // This would typically call Vesu's TVL function
            // For now, return a placeholder
            0
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_not_paused(self: @ContractState) {
            assert(!self.is_paused.read(), 'Contract is paused');
        }

        fn _assert_valid_amount(self: @ContractState, amount: u256) {
            assert(amount > 0, 'Amount must be positive');
        }

        fn _assert_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), 'Only owner allowed');
        }

        fn update_yield_rate(ref self: ContractState, token: ContractAddress, new_rate: u256) {
            self._assert_owner();
            self.yield_rates.entry(token).write(new_rate);
            
            self.emit(RateUpdated {
                token,
                new_rate,
                timestamp: starknet::get_block_timestamp(),
            });
        }

        fn emergency_pause(ref self: ContractState) {
            self._assert_owner();
            self.is_paused.write(true);
            
            self.emit(EmergencyPause {
                timestamp: starknet::get_block_timestamp(),
            });
        }

        fn unpause(ref self: ContractState) {
            self._assert_owner();
            self.is_paused.write(false);
        }
    }
}

// External dispatcher for Vesu protocol
use crate::interfaces::defi_protocol::IVesuProtocolDispatcher;
use crate::interfaces::defi_protocol::IVesuProtocolDispatcherTrait;