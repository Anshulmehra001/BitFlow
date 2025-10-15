use starknet::ContractAddress;

/// Generic interface for DeFi protocol integration
#[starknet::interface]
pub trait IDeFiProtocol<TContractState> {
    /// Deposits tokens into the DeFi protocol to earn yield
    /// @param token The token contract address to deposit
    /// @param amount The amount to deposit
    /// @return success True if deposit was successful
    fn deposit(ref self: TContractState, token: ContractAddress, amount: u256) -> bool;
    
    /// Withdraws tokens from the DeFi protocol
    /// @param token The token contract address to withdraw
    /// @param amount The amount to withdraw
    /// @return success True if withdrawal was successful
    fn withdraw(ref self: TContractState, token: ContractAddress, amount: u256) -> bool;
    
    /// Gets the current balance of deposited tokens
    /// @param token The token contract address
    /// @param user The user address
    /// @return balance The current balance
    fn get_balance(self: @TContractState, token: ContractAddress, user: ContractAddress) -> u256;
    
    /// Gets the current yield rate for a token
    /// @param token The token contract address
    /// @return rate The current annual yield rate in basis points
    fn get_yield_rate(self: @TContractState, token: ContractAddress) -> u256;
    
    /// Claims accumulated yield rewards
    /// @param token The token contract address
    /// @return claimed_amount The amount of yield claimed
    fn claim_yield(ref self: TContractState, token: ContractAddress) -> u256;
    
    /// Gets the total value locked in the protocol
    /// @param token The token contract address
    /// @return tvl The total value locked
    fn get_tvl(self: @TContractState, token: ContractAddress) -> u256;
}

/// Vesu protocol specific interface
#[starknet::interface]
pub trait IVesuProtocol<TContractState> {
    /// Supplies assets to Vesu lending pool
    /// @param asset The asset to supply
    /// @param amount The amount to supply
    /// @param on_behalf_of The address to supply on behalf of
    /// @return success True if supply was successful
    fn supply(
        ref self: TContractState,
        asset: ContractAddress,
        amount: u256,
        on_behalf_of: ContractAddress
    ) -> bool;
    
    /// Withdraws assets from Vesu lending pool
    /// @param asset The asset to withdraw
    /// @param amount The amount to withdraw
    /// @param to The address to withdraw to
    /// @return actual_amount The actual amount withdrawn
    fn withdraw(
        ref self: TContractState,
        asset: ContractAddress,
        amount: u256,
        to: ContractAddress
    ) -> u256;
    
    /// Gets the supply balance for a user
    /// @param asset The asset address
    /// @param user The user address
    /// @return balance The supply balance
    fn get_supply_balance(self: @TContractState, asset: ContractAddress, user: ContractAddress) -> u256;
    
    /// Gets the current supply APY
    /// @param asset The asset address
    /// @return apy The annual percentage yield in basis points
    fn get_supply_apy(self: @TContractState, asset: ContractAddress) -> u256;
}

/// Troves/Endurfi protocol specific interface
#[starknet::interface]
pub trait ITrovesProtocol<TContractState> {
    /// Stakes tokens in Troves protocol
    /// @param token The token to stake
    /// @param amount The amount to stake
    /// @return success True if staking was successful
    fn stake(ref self: TContractState, token: ContractAddress, amount: u256) -> bool;
    
    /// Unstakes tokens from Troves protocol
    /// @param token The token to unstake
    /// @param amount The amount to unstake
    /// @return success True if unstaking was successful
    fn unstake(ref self: TContractState, token: ContractAddress, amount: u256) -> bool;
    
    /// Gets the staked balance for a user
    /// @param token The token address
    /// @param user The user address
    /// @return balance The staked balance
    fn get_staked_balance(self: @TContractState, token: ContractAddress, user: ContractAddress) -> u256;
    
    /// Gets the current staking rewards rate
    /// @param token The token address
    /// @return rate The rewards rate in basis points
    fn get_rewards_rate(self: @TContractState, token: ContractAddress) -> u256;
    
    /// Claims staking rewards
    /// @param token The token address
    /// @return rewards_amount The amount of rewards claimed
    fn claim_rewards(ref self: TContractState, token: ContractAddress) -> u256;
}