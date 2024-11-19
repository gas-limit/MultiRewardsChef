# StandaloneMultiRewarder

The `StandaloneMultiRewarder` contract is a flexible reward distribution module designed for DeFi applications. It allows users who hold staked tokens, such as aTokens or LP tokens, to earn rewards in multiple tokens simultaneously. The contract is compatible with systems like `ChefIncentivesController` or a traditional MasterChef, enabling a highly modular and composable reward system.

---

## Features

- **Multi-Token Rewards**: Distribute rewards in multiple tokens for staking a single asset.
- **Custom Reward Rates**: Admins can define reward rates per token and update them dynamically.
- **Flexible Staking and Unstaking**: Users can stake and unstake their tokens while maintaining accurate reward calculations.
- **Efficient Reward Accounting**: Rewards are calculated and updated using scalable, gas-efficient methods.
- **Admin Controls**:
  - Add or remove reward tokens.
  - Adjust reward rates.
  - Deposit and withdraw reward tokens.

---

## How It Works

1. **Staking**:
   - Users stake tokens (`aToken`) into the contract.
   - Rewards accumulate based on the configured rates for each reward token.

2. **Reward Calculation**:
   - Rewards are calculated per second for each reward token.
   - Pending rewards are tracked efficiently, and users can claim them at any time.

3. **Claiming Rewards**:
   - Users can harvest their rewards for all eligible tokens in a single transaction.

4. **Admin Functions**:
   - Admins manage the reward tokens and their distribution rates.

---

## Deployment

### Prerequisites

- **Solidity Version**: `0.7.6`
- **Dependencies**:
  - OpenZeppelin Contracts:
    - `@openzeppelin/contracts/token/ERC20/IERC20.sol`
    - `@openzeppelin/contracts/token/ERC20/SafeERC20.sol`
    - `@openzeppelin/contracts/math/SafeMath.sol`

### Deployment Steps

1. Deploy the contract.
2. Assign the deployer as the `multiIncentiveAdmin`.

---

## Public Functions

### User Functions

#### `stakeIncentiveTokens(address _aToken, uint256 _amount)`
Stake tokens to start earning rewards.

- **Parameters**:
  - `_aToken`: The token address to be staked.
  - `_amount`: Amount of tokens to stake.

#### `_unstakeIncentiveTokens(address _aToken, uint256 _amount)`
Unstake tokens and claim rewards.

- **Parameters**:
  - `_aToken`: The token address to be unstaked.
  - `_amount`: Amount of tokens to unstake.

#### `previewEarned(address _user, address _aToken)`
View pending rewards for a specific user and staked token.

- **Returns**:
  - List of reward tokens and the corresponding pending rewards.

---

### Admin Functions

#### `addIncentiveReward(address _aToken, address _rewardToken, uint256 _rewardsPerSecond)`
Add a new reward token for a specific staked token.

- **Parameters**:
  - `_aToken`: The staked token address.
  - `_rewardToken`: The reward token address.
  - `_rewardsPerSecond`: Reward emission rate.

#### `removeIncentiveReward(address _aToken, address _rewardToken)`
Remove a reward token from the system.

#### `adjustRewardRate(address _aToken, address _rewardToken, uint256 _rewardsPerSecond)`
Adjust the reward emission rate for a reward token.

#### `depositReward(address _rewardAddress, uint256 _amount)`
Deposit reward tokens into the contract.

#### `withdrawReward(address _rewardAddress, uint256 _amount)`
Withdraw reward tokens from the contract.

---

## Events

- `multiStakeRecorded(address user, address aToken, uint256 amount)`
- `multiUnstakeRecorded(address user, address aToken, uint256 amount)`
- `multiRewardHarvested(address user, address aToken, address rewardToken, uint256 amount)`
- `multiRewardAdded(address aToken, address rewardToken, uint256 rewardsPerSecond)`
- `multiRewardRemoved(address aToken, address rewardToken)`
- `multiRewardUpdated(address aToken, address rewardToken, uint256 rewardsPerSecond)`
- `multiRewardDeposited(address rewardToken, uint256 amount)`
- `multiRewardWithdrawn(address rewardToken, uint256 amount)`

---

## Security Considerations

- Ensure reward rates and deposits are sufficient to avoid depletion of reward tokens prematurely.
- Perform rigorous audits before deploying to production environments.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Acknowledgments

This contract was designed to enhance flexibility in reward distribution for DeFi projects. It is shared as a public good to foster innovation in the space.
