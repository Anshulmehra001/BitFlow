#[starknet::contract]
pub mod TrovesAdapter {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };
    use crate::interfaces::defi_protocol::{IDeFiProtocol, ITrovesProtocol};
    use crate::types::BitFlowError;

    #[storage]
    struct Storage {
        // Troves protocol contract address
        troves_contract: ContractAddress,
        // Mapping from token to user staked balances
        user_staked_balances: Map<(ContractAddress, ContractAddress), u256>,
        // Mapping from token to user pending rewards
        user_pending_rewards: Map<(ContractAddress, ContractAddress), u256>,
        // Mapping from token to rewards rates
        rewards_rates: Map<ContractAddress, u256>,
        // Owner of the adapter
        owner: ContractAddress,
        // Emergency pause state
        is_paused: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Staked: Staked,
        Unstaked: Unstaked,
        RewardsClaimed: RewardsClaimed,
        RateUpdated: RateUpdated,
        EmergencyPause: EmergencyPause,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Staked {
        pub user: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Unstaked {
        pub user: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RewardsClaimed {
        pub user: ContractAddress,
        pub token: ContractAddress,
        pub rewards_amount: u256,
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
    fn constructor(ref self: ContractState, troves_contract: ContractAddress, owner: ContractAddress) {
        self.troves_contract.write(troves_contract);
        self.owner.write(owner);
        self.is_paused.write(false);
    }

    #[abi(embed_v0)]
    impl DeFiProtocolImpl of IDeFiProtocol<ContractState> {
        fn deposit(ref self: ContractState, token: ContractAddress, amount: u256) -> bool {
            self._assert_not_paused();
            self._assert_valid_amount(amount);
            
            let caller = get_caller_address();
            
            // Call Troves protocol to stake tokens
            let troves_contract = self.troves_contract.read();
            let troves_dispatcher = ITrovesProtocolDispatcher { contract_address: troves_contract };
            
            let success = troves_dispatcher.stake(token, amount);
            
            if success {
                // Update user staked balance
                let current_balance = self.user_staked_balances.entry((token, caller)).read();
                self.user_staked_balances.entry((token, caller)).write(current_balance + amount);
                
                self.emit(Staked {
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
            let current_balance = self.user_staked_balances.entry((token, caller)).read();
            
            assert(current_balance >= amount, 'Insufficient staked balance');
            
            // Call Troves protocol to unstake tokens
            let troves_contract = self.troves_contract.read();
            let troves_dispatcher = ITrovesProtocolDispatcher { contract_address: troves_contract };
            
            let success = troves_dispatcher.unstake(token, amount);
            
            if success {
                // Update user staked balance
                self.user_staked_balances.entry((token, caller)).write(current_balance - amount);
                
                self.emit(Unstaked {
                    user: caller,
                    token,
                    amount,
                    timestamp: starknet::get_block_timestamp(),
                });
            }
            
            success
        }

        fn get_balance(self: @ContractState, token: ContractAddress, user: ContractAddress) -> u256 {
            self.user_staked_balances.entry((token, user)).read()
        }

        fn get_yield_rate(self: @ContractState, token: ContractAddress) -> u256 {
            // Try to get live rate from Troves, fallback to cached rate
            let troves_contract = self.troves_contract.read();
            let troves_dispatcher = ITrovesProtocolDispatcher { contract_address: troves_contract };
            
            let live_rate = troves_dispatcher.get_rewards_rate(token);
            if live_rate > 0 {
                live_rate
            } else {
                self.rewards_rates.entry(token).read()
            }
        }

        fn claim_yield(ref self: ContractState, token: ContractAddress) -> u256 {
            self._assert_not_paused();
            
            let caller = get_caller_address();
            
            // Call Troves protocol to claim rewards
            let troves_contract = self.troves_contract.read();
            let troves_dispatcher = ITrovesProtocolDispatcher { contract_address: troves_contract };
            
            let rewards_amount = troves_dispatcher.claim_rewards(token);
            
            if rewards_amount > 0 {
                // Update pending rewards (reset to 0 after claiming)
                self.user_pending_rewards.entry((token, caller)).write(0);
                
                self.emit(RewardsClaimed {
                    user: caller,
                    token,
                    rewards_amount,
                    timestamp: starknet::get_block_timestamp(),
                });
            }
            
            rewards_amount
        }

        fn get_tvl(self: @ContractState, token: ContractAddress) -> u256 {
            // This would typically call Troves' TVL function
            // For now, return a placeholder
            0
        }
    }

    #[abi(embed_v0)]
    impl TrovesProtocolImpl of ITrovesProtocol<ContractState> {
        fn stake(ref self: ContractState, token: ContractAddress, amount: u256) -> bool {
            self.deposit(token, amount)
        }

        fn unstake(ref self: ContractState, token: ContractAddress, amount: u256) -> bool {
            self.withdraw(token, amount)
        }

        fn get_staked_balance(self: @ContractState, token: ContractAddress, user: ContractAddress) -> u256 {
            self.get_balance(token, user)
        }

        fn get_rewards_rate(self: @ContractState, token: ContractAddress) -> u256 {
            self.get_yield_rate(token)
        }

        fn claim_rewards(ref self: ContractState, token: ContractAddress) -> u256 {
            self.claim_yield(token)
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

        fn update_rewards_rate(ref self: ContractState, token: ContractAddress, new_rate: u256) {
            self._assert_owner();
            self.rewards_rates.entry(token).write(new_rate);
            
            self.emit(RateUpdated {
                token,
                new_rate,
                timestamp: starknet::get_block_timestamp(),
            });
        }

        fn get_pending_rewards(self: @ContractState, token: ContractAddress, user: ContractAddress) -> u256 {
            self.user_pending_rewards.entry((token, user)).read()
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

// External dispatcher for Troves protocol
use crate::interfaces::defi_protocol::ITrovesProtocolDispatcher;
use crate::interfaces::defi_protocol::ITrovesProtocolDispatcherTrait;