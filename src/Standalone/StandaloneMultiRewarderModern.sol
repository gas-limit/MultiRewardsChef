// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title StandaloneMultiRewarder
 * @dev A standalone multi-token reward distribution contract for staking tokens such as aTokens or LP tokens.
 * Users earn rewards in multiple tokens simultaneously, with flexible staking and admin controls.
 */
contract StandaloneMultiRewarderModern is Ownable2Step {

    using SafeERC20 for IERC20;

    /// @notice Address of the admin responsible for managing incentives
    address public multiIncentiveAdmin;

    /// @notice Maps aToken addresses to the total staked amount
    mapping(address => uint256) public multiTotalStaked;

    /// @notice Maps aToken and user addresses to the user's staked amount
    mapping(address => mapping(address => uint256)) public multiUserStaked;

    /// @notice Maps aToken addresses to an array of reward tokens
    mapping(address => address[]) public multiRewardTokens;

    /// @notice Maps reward token addresses to a boolean indicating if it is a multi-reward token
    mapping(address => bool) public isMultiRewardToken;

    /// @notice Maps aToken and reward token addresses to the reward per token value
    mapping(address => mapping(address => uint256)) public multiRewardPerToken;

    /// @notice Tracks user-specific reward offsets for accurate reward calculations
    mapping(address => mapping(address => mapping(address => uint256))) public multiUserRewardOffset;

    /// @notice Tracks accumulated pending rewards for users per reward token
    mapping(address => mapping(address => uint256)) public multiUserPendingRewards;

    /// @notice Tracks reward rates per aToken and reward token
    mapping(address => mapping(address => uint256)) public multiRewardPerSecond;

    /// @notice Tracks the last update time for rewards per aToken and reward token
    mapping(address => mapping(address => uint256)) public lastMultiUpdateTime;

    /// @dev Scale factor for reward calculations
    uint256 internal constant SCALE = 1e24;

    error ZeroAmount();
    error UnauthorizedCaller();
    error InsufficientBalance();
    error RewardExists();
    error RewardDoesNotExist();

    /// @dev Emitted when a user stakes tokens
    event multiStakeRecorded(address indexed user, address indexed aToken, uint256 amount);
    /// @dev Emitted when a user unstakes tokens
    event multiUnstakeRecorded(address indexed user, address indexed aToken, uint256 amount);
    /// @dev Emitted when a user claims rewards
    event multiRewardHarvested(
        address indexed user,
        address indexed aToken,
        address indexed rewardToken,
        uint256 amount
    );
    /// @dev Emitted when a new reward token is added
    event multiRewardAdded(
        address indexed aToken,
        address indexed rewardToken,
        uint256 rewardsPerSecond
    );
    /// @dev Emitted when a reward token is removed
    event multiRewardRemoved(address indexed aToken, address indexed rewardToken);
    /// @dev Emitted when a reward rate is updated
    event multiRewardUpdated(
        address indexed aToken,
        address indexed rewardToken,
        uint256 rewardsPerSecond
    );
    /// @dev Emitted when reward tokens are deposited
    event multiRewardDeposited(address indexed rewardToken, uint256 amount);
    /// @dev Emitted when reward tokens are withdrawn
    event multiRewardWithdrawn(address indexed rewardToken, uint256 amount);

    /**
     * @dev Initializes the contract and sets the deployer as the multiIncentiveAdmin.
     */
    constructor() Ownable2Step() Ownable(msg.sender){
        
    }


    // ╒═════════════════════✰°
    //     USER FUNCTIONS
    // °✰════════════════════╛

    /**
     * @notice Stakes tokens to earn rewards.
     * @param _aToken The address of the token to be staked.
     * @param _amount The amount of tokens to stake.
     */
    function stakeIncentiveTokens(address _aToken, uint256 _amount) external {
        if(_amount == 0) revert ZeroAmount();
        calculateUserPending(msg.sender, _aToken);
        // Update rewards before modifying stakes to ensure proper accounting
        updateMultiRewardAccounting(_aToken);
        
        multiTotalStaked[_aToken] = multiTotalStaked[_aToken] + _amount;
        multiUserStaked[msg.sender][_aToken] = multiUserStaked[msg.sender][_aToken] + (_amount);

        address[] memory rewardTokenList = multiRewardTokens[_aToken];
        uint256 rewardTokenCount = rewardTokenList.length;
        
        for (uint256 i = 0; i < rewardTokenCount; i++) {
            address rewardToken = rewardTokenList[i];
            // Set the offset to current rewardPerToken to start counting from this point
            multiUserRewardOffset[msg.sender][_aToken][rewardToken] = 
                _simulateRewardPerToken(_aToken, rewardToken, multiTotalStaked[_aToken] - _amount);
        }

       IERC20(_aToken).safeTransferFrom(msg.sender, address(this), _amount);

        emit multiStakeRecorded(msg.sender, _aToken, _amount);
    }
    /**
     * @notice Unstakes tokens and claims any earned rewards.
     * @param _aToken The address of the token to be unstaked.
     * @param _amount The amount of tokens to unstake.
     */
    function unstakeIncentiveTokens(address _aToken, uint256 _amount) external {
        if(_amount == 0) revert ZeroAmount();
        if(_amount > multiUserStaked[msg.sender][_aToken]) revert InsufficientBalance();
        
        claimMultiRewards(_aToken);
        uint256 stakedAmount = multiUserStaked[msg.sender][_aToken];
        if (stakedAmount < _amount) revert InsufficientBalance();
        multiUserStaked[msg.sender][_aToken] = stakedAmount - _amount;
        multiTotalStaked[_aToken] = multiTotalStaked[_aToken] - _amount;

        IERC20(_aToken).safeTransfer(msg.sender, _amount);

        emit multiUnstakeRecorded(msg.sender, _aToken, _amount);
    }

    /**
     * @notice Claims all pending rewards for a specific staked token.
     * @param _aToken The address of the staked token.
     */
    function claimMultiRewards(address _aToken) public {
        updateMultiRewardAccounting(_aToken);
        address[] memory rewardTokenList = multiRewardTokens[_aToken];
        uint256 rewardTokenCount = rewardTokenList.length;
        for (uint256 i = 0; i < rewardTokenCount; i++) {
            address rewardToken = rewardTokenList[i];
            uint256 earnedAmountScaled = (multiRewardPerToken[_aToken][rewardToken] - multiUserRewardOffset[msg.sender][_aToken][rewardToken]) 
            * multiUserStaked[msg.sender][_aToken];
            uint256 earnedAmountWithoutPending = earnedAmountScaled / SCALE;
            uint256 earnedAmountActual = earnedAmountWithoutPending + multiUserPendingRewards[msg.sender][rewardToken];
            if (earnedAmountActual == 0) {
                continue;
            }
            multiUserRewardOffset[msg.sender][_aToken][rewardToken] = multiRewardPerToken[_aToken][rewardToken];
            IERC20(rewardToken).safeTransfer(msg.sender, earnedAmountActual);

            emit multiRewardHarvested(msg.sender, _aToken, rewardToken, earnedAmountActual);
        }
    }

    // ╒═════════════════════════✰°
    //     INTERNAL ACCOUNTING
    // °✰════════════════════════╛

    /**
     * @notice Updates reward accounting for a specific staked token.
     * @param _aToken The address of the staked token.
     */
    function updateMultiRewardAccounting(address _aToken) internal {
        if(multiTotalStaked[_aToken] == 0) {
            return;
        }
        address[] memory rewardTokenList = multiRewardTokens[_aToken];
        address rewardToken;
        uint256 rewardTokenCount = rewardTokenList.length;
        for (uint256 i = 0; i < rewardTokenCount; i++) {
            rewardToken = rewardTokenList[i];
            uint256 timeElapsed = block.timestamp -
                lastMultiUpdateTime[_aToken][rewardToken];
            uint256 rewardToAdd = timeElapsed * (
                multiRewardPerSecond[_aToken][rewardToken]);
            multiRewardPerToken[_aToken][rewardToken] += 
                rewardToAdd
                 * (SCALE)
                 / (multiTotalStaked[_aToken]);

            lastMultiUpdateTime[_aToken][rewardToken] = block.timestamp;
        }
    }

    /**
     * @notice Calculates pending rewards for a user and updates their pending rewards.
     * @param _user The address of the user.
     * @param _aToken The address of the staked token.
     */
    function calculateUserPending(address _user, address _aToken) internal {
        (address[] memory rewardTokenList, uint256[] memory earnedAmounts) = previewEarned(
            _user,
            _aToken
        );
        for(uint256 i = 0; i < rewardTokenList.length; i++) {
            address rewardToken = rewardTokenList[i];
            multiUserPendingRewards[_user][rewardToken] += earnedAmounts[i];
        }
        
    }

    // ╒═════════════════════════✰°
    //        ADMIN FUNCTIONS
    // °✰════════════════════════╛

    /**
     * @notice Adds a new reward token for a specific staked token.
     * @param _aToken The address of the staked token.
     * @param _rewardToken The address of the reward token to add.
     * @param _rewardsPerSecond The rate at which rewards are distributed per second.
     */
    function addIncentiveReward(
        address _aToken,
        address _rewardToken,
        uint256 _rewardsPerSecond
    ) external onlyOwner {
        address[] memory rewardTokenList = multiRewardTokens[_aToken];
        // check if reward token already exists
        for (uint256 i = 0; i < rewardTokenList.length; i++) {
            if(rewardTokenList[i] == _rewardToken) revert RewardExists();
        }

        multiRewardTokens[_aToken].push(_rewardToken);
        multiRewardPerSecond[_aToken][_rewardToken] = _rewardsPerSecond;
        lastMultiUpdateTime[_aToken][_rewardToken] = block.timestamp;
        isMultiRewardToken[_rewardToken] = true;

        emit multiRewardAdded(_aToken, _rewardToken, _rewardsPerSecond);
    }

    /**
     * @notice Removes a reward token for a specific staked token.
     * @param _aToken The address of the staked token.
     * @param _rewardToken The address of the reward token to remove.
     */
    function removeIncentiveReward(
        address _aToken,
        address _rewardToken
    ) external onlyOwner {
        updateMultiRewardAccounting(_aToken);
        if(multiRewardPerSecond[_aToken][_rewardToken] == 0) revert RewardDoesNotExist();

        // Stop accumulating new rewards
        multiRewardPerSecond[_aToken][_rewardToken] = 0;

        emit multiRewardRemoved(_aToken, _rewardToken);
    }


    /**
     * @notice Updates the reward rate for a specific staked token and reward token.
     * @param _aToken The address of the staked token.
     * @param _rewardToken The address of the reward token.
     * @param _rewardsPerSecond The new reward rate per second.
     */
    function adjustRewardRate(address _aToken, address _rewardToken, uint256 _rewardsPerSecond) external onlyOwner {
        if(multiRewardPerSecond[_aToken][_rewardToken] == 0) revert RewardDoesNotExist();
        updateMultiRewardAccounting(_aToken);
        multiRewardPerSecond[_aToken][_rewardToken] = _rewardsPerSecond;
        emit multiRewardUpdated(_aToken, _rewardToken, _rewardsPerSecond);
    }

    /**
     * @notice Deposits reward tokens into the contract.
     * @param _rewardAddress The address of the reward token.
     * @param _amount The amount of reward tokens to deposit.
     */
    function depositReward(address _rewardAddress, uint256 _amount) external onlyOwner {
        IERC20(_rewardAddress).safeTransferFrom(msg.sender, address(this), _amount);
        emit multiRewardDeposited(_rewardAddress, _amount);
    }

    /**
     * @notice Withdraws reward tokens from the contract.
     * @param _rewardAddress The address of the reward token.
     * @param _amount The amount of reward tokens to withdraw.
     */
    function withdrawReward(address _rewardAddress, uint256 _amount) external onlyOwner {
        IERC20(_rewardAddress).safeTransfer(msg.sender, _amount);
        emit multiRewardWithdrawn(_rewardAddress, _amount);
    }

    // ╒═════════════════════════✰°
    //     USER PREVIEW REWARDS
    // °✰════════════════════════╛

    /**
     * @notice Previews the rewards earned by a user for a specific staked token.
     * @param _user The address of the user.
     * @param _aToken The address of the staked token.
     * @return multiRewardTokens_ The array of reward token addresses.
     * @return earnedAmounts_ The array of earned reward amounts corresponding to each reward token.
     */
    function previewEarned(address _user, address _aToken)
        public
        view
        returns (address[] memory multiRewardTokens_, uint256[] memory earnedAmounts_)
    {
        address[] memory rewardTokenList = multiRewardTokens[_aToken];
        uint256 rewardTokenCount = rewardTokenList.length;
        multiRewardTokens_ = new address[](rewardTokenCount);
        earnedAmounts_ = new uint256[](rewardTokenCount);
        uint256 totalStakedAmount = multiTotalStaked[_aToken];
        uint256 userStakedAmount = multiUserStaked[_user][_aToken];

        if (userStakedAmount == 0 || totalStakedAmount == 0) {
            // No staked amount or no total staked amount, earned is zero
            return (multiRewardTokens_, earnedAmounts_);
        }

        for (uint256 i = 0; i < rewardTokenCount; i++) {
            address rewardToken = rewardTokenList[i];
            uint256 simulatedRewardPerToken = _simulateRewardPerToken(
                _aToken,
                rewardToken,
                totalStakedAmount
            );
            uint256 earnedAmountActual = _calculateEarnedAmount(
                _user,
                _aToken,
                rewardToken,
                simulatedRewardPerToken,
                userStakedAmount
            );
            earnedAmounts_[i] = earnedAmountActual + multiUserPendingRewards[_user][rewardToken];
            multiRewardTokens_[i] = rewardToken;
        }
    }

    /**
     * @notice Simulates the reward per token for a specific staked token and reward token.
     * @param _aToken The address of the staked token.
     * @param _rewardToken The address of the reward token.
     * @param totalStakedAmount The total amount of staked tokens.
     * @return simulatedRewardPerToken The simulated reward per token value.
     */
    function _simulateRewardPerToken(
        address _aToken,
        address _rewardToken,
        uint256 totalStakedAmount
    ) internal view returns (uint256) {
        if (totalStakedAmount == 0) {
            return multiRewardPerToken[_aToken][_rewardToken];
        }
        
        uint256 timeElapsed = block.timestamp - lastMultiUpdateTime[_aToken][_rewardToken];
        uint256 rewardToAdd = timeElapsed * (multiRewardPerSecond[_aToken][_rewardToken]);
        uint256 simulatedRewardPerToken = 
            multiRewardPerToken[_aToken][_rewardToken] 
            + rewardToAdd * (SCALE) 
            / (totalStakedAmount);

        return simulatedRewardPerToken;
    }

    /**
     * @notice Calculates the earned rewards for a user.
     * @param _user The address of the user.
     * @param _aToken The address of the staked token.
     * @param _rewardToken The address of the reward token.
     * @param simulatedRewardPerToken The simulated reward per token value.
     * @param userStakedAmount The amount of tokens staked by the user.
     * @return earnedAmountActual The actual reward amount earned by the user.
     */
    function _calculateEarnedAmount(
        address _user,
        address _aToken,
        address _rewardToken,
        uint256 simulatedRewardPerToken,
        uint256 userStakedAmount
    ) internal view returns (uint256) {
        uint256 userRewardPerTokenOffset = multiUserRewardOffset[_user][_aToken][_rewardToken];
        uint256 earnedAmountScaled = 
            simulatedRewardPerToken 
            - userRewardPerTokenOffset
            * (userStakedAmount);
        uint256 earnedAmountActual = earnedAmountScaled / SCALE;
        return earnedAmountActual;
    }


    
}