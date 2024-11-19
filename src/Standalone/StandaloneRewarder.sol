// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "../dependencies/openzeppelin/contracts/IERC20.sol";
import "../dependencies/openzeppelin/contracts/SafeERC20.sol";
import "../dependencies/openzeppelin/contracts/SafeMath.sol";

contract MultiIncentiveModule {

    using SafeMath for uint256;

    address multiIncentiveAdmin;

    // aToken address => total staked amount
    mapping(address => uint256) public multiTotalStaked;
    // aToken address => staked amount
    mapping(address => mapping(address => uint256)) public multiUserStaked;
    // aToken address => rewardToken array
    mapping(address => address[]) public multiRewardTokens;
    // rewardToken address => isMultiRewardToken
    mapping(address => bool) public isMultiRewardToken;
    // aTokenAddress => rewardTokenAddress => multiRewardPerToken
    mapping(address => mapping(address => uint256)) public multiRewardPerToken;
    // user address => aToken address => reward address => multiRewardPerTokenOffsetScaled
    mapping(address => mapping(address => mapping(address => uint256)))
        public multiUserRewardOffset;
    // user address => rewardToken address => accumulated rewards
    mapping(address => mapping(address => uint256)) public multiUserPendingRewards;
    // aToken address => rewardToken address => rewardPerSecond
    mapping(address => mapping(address => uint256)) public multiRewardPerSecond;
    // aToken address => rewardToken address => lastMultiUpdateTime
    mapping(address => mapping(address => uint256)) public lastMultiUpdateTime;

    uint256 internal constant SCALE = 1e24;

    event multiStakeRecorded(address user, address aToken, uint256 amount);
    event multiUnstakeRecorded(address user, address aToken, uint256 amount);
    event multiRewardHarvested(
        address user,
        address aToken,
        address rewardToken,
        uint256 amount
    );
    event multiRewardAdded(
        address aToken,
        address rewardToken,
        uint256 rewardsPerSecond
    );
    event multiRewardRemoved(address aToken, address rewardToken);
    event multiRewardUpdated(
        address aToken,
        address rewardToken,
        uint256 rewardsPerSecond
    );
    event multiRewardDeposited(address rewardToken, uint256 amount);
    event multiRewardWithdrawn(address rewardToken, uint256 amount);

    modifier onlyIncentiveAdmin() {
        require(msg.sender == multiIncentiveAdmin, "caller is not the multiIncentiveAdmin");
        _;
    }

    constructor() {
        multiIncentiveAdmin = msg.sender;
    }

    // ╒═════════════════════✰°
    //     USER FUNCTIONS
    // °✰════════════════════╛

    // Stake aToken
    function _stakeIncentiveTokens(address _aToken, uint256 _amount, address _user) internal {
        require(_amount > 0, "amount must be greater than 0");
        calculateUserPending(_user, _aToken);
        // Update rewards before modifying stakes to ensure proper accounting
        updateMultiRewardAccounting(_aToken);
        
        multiTotalStaked[_aToken] = multiTotalStaked[_aToken].add(_amount);
        multiUserStaked[_user][_aToken] = multiUserStaked[_user][_aToken].add(_amount);

        address[] memory rewardTokenList = multiRewardTokens[_aToken];
        uint256 rewardTokenCount = rewardTokenList.length;
        
        for (uint256 i = 0; i < rewardTokenCount; i++) {
            address rewardToken = rewardTokenList[i];
            // Set the offset to current rewardPerToken to start counting from this point
            multiUserRewardOffset[_user][_aToken][rewardToken] = 
                _simulateRewardPerToken(_aToken, rewardToken, multiTotalStaked[_aToken].sub(_amount));
        }

        emit multiStakeRecorded(_user, _aToken, _amount);
    }

    // Withdraw aToken
    function _unstakeIncentiveTokens(address _aToken, uint256 _amount, address _user) internal {
        require(_amount > 0, "amount must be greater than 0");
        // assume check for sufficient staked amount is done in parent contract
        _claimMultiRewards(_aToken, _user);
        uint256 stakedAmount = multiUserStaked[_user][_aToken];
        require(stakedAmount >= _amount, "insufficient staked amount");
        multiUserStaked[_user][_aToken] = stakedAmount.sub(_amount);
        multiTotalStaked[_aToken] = multiTotalStaked[_aToken].sub(_amount);

        emit multiUnstakeRecorded(_user, _aToken, _amount);
    }

    // Harvest rewards
    function _claimMultiRewards(address _aToken, address _user) internal {
        updateMultiRewardAccounting(_aToken);
        address[] memory rewardTokenList = multiRewardTokens[_aToken];
        uint256 rewardTokenCount = rewardTokenList.length;
        for (uint256 i = 0; i < rewardTokenCount; i++) {
            address rewardToken = rewardTokenList[i];
            uint256 earnedAmountScaled = (multiRewardPerToken[_aToken][rewardToken] -
                multiUserRewardOffset[_user][_aToken][
                    rewardToken
                ]) * multiUserStaked[_user][_aToken];
            uint256 earnedAmountWithoutPending = earnedAmountScaled.div(SCALE);
            uint256 earnedAmountActual = earnedAmountWithoutPending + multiUserPendingRewards[_user][rewardToken];
            if (earnedAmountActual == 0) {
                continue;
            }
            multiUserRewardOffset[_user][_aToken][
                rewardToken
            ] = multiRewardPerToken[_aToken][rewardToken];
            // IERC20(rewardToken).transfer(_user, earnedAmountActual);
            emit multiRewardHarvested(_user, _aToken, rewardToken, earnedAmountActual);
        }
    }

    // ╒═════════════════════════✰°
    //     INTERNAL ACCOUNTING
    // °✰════════════════════════╛

    // Update reward accounting
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
            uint256 rewardToAdd = timeElapsed.mul(
                multiRewardPerSecond[_aToken][rewardToken]);
            multiRewardPerToken[_aToken][rewardToken] += rewardToAdd
                .mul(SCALE)
                .div(multiTotalStaked[_aToken]);

            lastMultiUpdateTime[_aToken][rewardToken] = block.timestamp;
        }
    }

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

    // Add a new reward to a specific aToken
    function addIncentiveReward(
        address _aToken,
        address _rewardToken,
        uint256 _rewardsPerSecond
    ) external onlyIncentiveAdmin {
        address[] memory rewardTokenList = multiRewardTokens[_aToken];
        // check if reward token already exists
        for (uint256 i = 0; i < rewardTokenList.length; i++) {
            require(
                rewardTokenList[i] != _rewardToken,
                "reward token already exists"
            );
        }

        multiRewardTokens[_aToken].push(_rewardToken);
        multiRewardPerSecond[_aToken][_rewardToken] = _rewardsPerSecond;
        lastMultiUpdateTime[_aToken][_rewardToken] = block.timestamp;
        isMultiRewardToken[_rewardToken] = true;

        emit multiRewardAdded(_aToken, _rewardToken, _rewardsPerSecond);
    }

    // Remove a reward from a specific aToken
    function removeIncentiveReward(
        address _aToken,
        address _rewardToken
    ) external onlyIncentiveAdmin {
        updateMultiRewardAccounting(_aToken);
        require(multiRewardPerSecond[_aToken][_rewardToken] != 0, "reward token does not exist");

        // Stop accumulating new rewards
        multiRewardPerSecond[_aToken][_rewardToken] = 0;

        emit multiRewardRemoved(_aToken, _rewardToken);
    }


    // Update reward per second for a specific aToken
    function adjustRewardRate(address _aToken, address _rewardToken, uint256 _rewardsPerSecond) external onlyIncentiveAdmin {
        require(multiRewardPerSecond[_aToken][_rewardToken] != 0, "reward token does not exist");
        updateMultiRewardAccounting(_aToken);
        multiRewardPerSecond[_aToken][_rewardToken] = _rewardsPerSecond;
        emit multiRewardUpdated(_aToken, _rewardToken, _rewardsPerSecond);
    }

    function depositReward(address _rewardAddress, uint256 _amount) external onlyIncentiveAdmin {
        IERC20(_rewardAddress).transferFrom(msg.sender, address(this), _amount);
        emit multiRewardDeposited(_rewardAddress, _amount);
    }

    function withdrawReward(address _rewardAddress, uint256 _amount) external onlyIncentiveAdmin {
        IERC20(_rewardAddress).transfer(msg.sender, _amount);
        emit multiRewardWithdrawn(_rewardAddress, _amount);
    }

    // ╒═════════════════════════✰°
    //     USER PREVIEW REWARDS
    // °✰════════════════════════╛
    
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

    function _simulateRewardPerToken(
        address _aToken,
        address _rewardToken,
        uint256 totalStakedAmount
    ) internal view returns (uint256) {
        if (totalStakedAmount == 0) {
            return multiRewardPerToken[_aToken][_rewardToken];
        }
        
        uint256 timeElapsed = block.timestamp - lastMultiUpdateTime[_aToken][_rewardToken];
        uint256 rewardToAdd = timeElapsed.mul(multiRewardPerSecond[_aToken][_rewardToken]);
        uint256 simulatedRewardPerToken = multiRewardPerToken[_aToken][_rewardToken].add(
            rewardToAdd.mul(SCALE).div(totalStakedAmount)
        );
        return simulatedRewardPerToken;
    }

    function _calculateEarnedAmount(
        address _user,
        address _aToken,
        address _rewardToken,
        uint256 simulatedRewardPerToken,
        uint256 userStakedAmount
    ) internal view returns (uint256) {
        uint256 userRewardPerTokenOffset = multiUserRewardOffset[_user][_aToken][_rewardToken];
        uint256 earnedAmountScaled = simulatedRewardPerToken.sub(userRewardPerTokenOffset)
            .mul(userStakedAmount);
        uint256 earnedAmountActual = earnedAmountScaled.div(SCALE);
        return earnedAmountActual;
    }


    
}