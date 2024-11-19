// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
import {Test} from "forge-std/Test.sol";
pragma abicoder v2;

import { MultiRewardLogic } from "./MultiRewardLogic.sol";


contract MultiIncentiveModuleTest is Test {
    MultiRewardLogic multiIncentiveModule;

    address aToken = address(0x1);
    address incentiveToken1 = address(0x2);
    address incentiveToken2 = address(0x3);
    address USER_B = address(0x4);

    event LogRewardPreview(address[] rewardTokens, uint256[] rewardamounts);
   
    function setUp() public {
        multiIncentiveModule = new MultiRewardLogic();
        multiIncentiveModule.addIncentiveReward(
            aToken,
            incentiveToken1,
            200
        );
        multiIncentiveModule.addIncentiveReward(
            aToken,
            incentiveToken2,
            100
        );

    }

    function testRewardAmountAfterOnePeriod() public {

        multiIncentiveModule.stakeIncentiveTokens(
            aToken,
            1 ether,
            address(this)
        );

        vm.warp(block.timestamp + 1 weeks);

        (address[] memory rewardTokens, uint256[] memory rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        assertEq(rewardTokens.length, 2);
        assertEq(rewardamounts[0], 120960000);
        assertEq(rewardamounts[1], 60480000);
        
        emit LogRewardPreview(rewardTokens, rewardamounts);

    }


    function testRewardAmountAfterDifferentPeriods() public {
        // 2. make sure amounts out are correct after different periods
        multiIncentiveModule.stakeIncentiveTokens(
            aToken,
            1 ether,
            address(this)
        );

        vm.warp(block.timestamp + 4 weeks);

        (address[] memory rewardTokens, uint256[] memory rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        emit LogRewardPreview(rewardTokens, rewardamounts);

        assertEq(rewardamounts[0], 483840000); // 0.00004134% less than expected
        assertEq(rewardamounts[1], 241920000);

    }

    function testRewardAmountWithMultipleUsersAfterDifferentPeriods() public {
        // User A stakes
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));

        // Advance time by 4 weeks
        vm.warp(block.timestamp + 4 weeks);

        // Calculate rewards for User A
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        uint256 expectedRewardToken1 = 483840000; 
        uint256 expectedRewardToken2 = 241920000; 

        assertEq(rewardAmounts[0], expectedRewardToken1);
        assertEq(rewardAmounts[1], expectedRewardToken2);

        // User B stakes
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, USER_B);

        // Verify that User B has no rewards immediately after staking
        (rewardTokens, rewardAmounts) = multiIncentiveModule.previewEarned(USER_B, aToken);

        assertEq(rewardAmounts[0], 0);
        assertEq(rewardAmounts[1], 0);

        // Advance time by another 4 weeks (total 8 weeks)
        vm.warp(block.timestamp + 4 weeks);

        // Calculate rewards for User B
        (rewardTokens, rewardAmounts) = multiIncentiveModule.previewEarned(USER_B, aToken);

        assertEq(rewardAmounts[0], 241920000);
        assertEq(rewardAmounts[1], 120960000);

        // Calculate rewards for User A
        (rewardTokens, rewardAmounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        // Expected total rewards for User A
        expectedRewardToken1 = 483840000 + 241920000;
        expectedRewardToken2 = 241920000 + 120960000;

        assertEq(rewardAmounts[0], expectedRewardToken1);
        assertEq(rewardAmounts[1], expectedRewardToken2);
    }

    function testRewardAmountAfterDepositingMore() public {
        // Step 1: User A stakes 1 ether at t = 0
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));

        // Step 2: Advance time by 4 weeks
        vm.warp(block.timestamp + 4 weeks);

        // Step 3: Calculate rewards for User A
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        // Expected rewards after 4 weeks
        uint256 expectedRewardToken1 = 483840000; 
        uint256 expectedRewardToken2 = 241920000;

        assertEq(rewardAmounts[0], expectedRewardToken1);
        assertEq(rewardAmounts[1], expectedRewardToken2);

        // Step 4: Stake more tokens
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));

        // Step 5: Calculate rewards for User A again
        (rewardTokens, rewardAmounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        // Rewards should still include the previous amount since we haven't claimed yet
        assertEq(rewardAmounts[0], expectedRewardToken1);
        assertEq(rewardAmounts[1], expectedRewardToken2);

        // Step 6: Advance time by another 4 weeks (total 8 weeks)
        vm.warp(block.timestamp + 4 weeks);

        // Step 7: Calculate rewards for User A again
        (rewardTokens, rewardAmounts) = multiIncentiveModule.previewEarned(address(this), aToken);
    }

    function testRewardAmountAfterWithdrawAndRedeposit() public {
        // 3. make sure amounts out are correct after withdrawing and redepositing
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));

        (address[] memory rewardTokens, uint256[] memory rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);
        
        assertEq(rewardamounts[0], 0);
        assertEq(rewardamounts[1], 0);

        vm.warp(block.timestamp + 4 weeks);

        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);
        assertEq(rewardamounts[0], 483840000);
        assertEq(rewardamounts[1], 241920000);
        

        multiIncentiveModule.unstakeIncentiveTokens(aToken, 1 ether, address(this));

        multiIncentiveModule.previewEarned(address(this), aToken);

        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);
        assertEq(rewardamounts[0], 0);
        assertEq(rewardamounts[1], 0);
 

        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));

        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        assertEq(rewardamounts[0], 0);
        assertEq(rewardamounts[1], 0);

    }

    function testClaimRewards() public {
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));

        (address[] memory rewardTokens, uint256[] memory rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);
        
        assertEq(rewardamounts[0], 0);
        assertEq(rewardamounts[1], 0);

        vm.warp(block.timestamp + 4 weeks);

        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);
        assertEq(rewardamounts[0], 483840000);
        assertEq(rewardamounts[1], 241920000);

        multiIncentiveModule.claimMultiRewards(aToken, address(this));

        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        assertEq(rewardamounts[0], 0);
        assertEq(rewardamounts[1], 0);

    }

    function testFail_AdminCannotAddSameIncentive() public {
        // 6. make sure admin cannot add the same incentive

        multiIncentiveModule.addIncentiveReward(
            aToken,
            incentiveToken1,
            200
        );


    }

    function testAdminCanRemoveIncentive() public {
        // 7. make sure admin can remove incentives

        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));

        vm.warp(block.timestamp + 4 weeks);

        multiIncentiveModule.removeIncentiveReward(
            aToken,
            incentiveToken1
        );

        multiIncentiveModule.removeIncentiveReward(
            aToken,
            incentiveToken2
        );

        (address[] memory rewardTokens, uint256[] memory rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        assertEq(rewardamounts[0], 483840000);
        assertEq(rewardamounts[1], 241920000);

        vm.warp(block.timestamp + 4 weeks);

        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        assertEq(rewardamounts[0], 483840000);
        assertEq(rewardamounts[1], 241920000);
        
    }

    function testRewardAdjustment() public {
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));

        vm.warp(block.timestamp + 4 weeks);

        (address[] memory rewardTokens, uint256[] memory rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        assertEq(rewardamounts[0], 483840000);
        assertEq(rewardamounts[1], 241920000);

        multiIncentiveModule.adjustRewardRate(
            aToken,
            incentiveToken2,
            200
        );

        vm.warp(block.timestamp + 4 weeks);

        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        assertEq(rewardamounts[0], 483840000 * 2);
        assertEq(rewardamounts[1], 241920000 * 3);

    }

    function testFailZeroAmountStake() public {
        // Attempt to stake zero tokens
        multiIncentiveModule.stakeIncentiveTokens(aToken, 0, address(this));

    }

    function testFailZeroAmountUnstake() public {
        // Attempt to unstake zero tokens
        multiIncentiveModule.unstakeIncentiveTokens(aToken, 0, address(this));

        // Verify that total staked amount remains zero
        assertEq(multiIncentiveModule.multiTotalStaked(aToken), 0);
        assertEq(multiIncentiveModule.multiUserStaked(address(this), aToken), 0);
    }

    function testFail_UnstakeMoreThanStaked() public {
        // Stake some tokens
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));

        // Attempt to unstake more than staked
        multiIncentiveModule.unstakeIncentiveTokens(aToken, 2 ether, address(this));
    }

    function testFail_NonAdminCannotAddIncentiveReward() public {
        // Attempt to add an incentive reward as a non-admin user
        vm.prank(USER_B);
        multiIncentiveModule.addIncentiveReward(aToken, address(0x5), 100);
    }

    function testFail_NonAdminCannotRemoveIncentiveReward() public {
        vm.prank(USER_B);
        multiIncentiveModule.removeIncentiveReward(aToken, incentiveToken1);
    }

    function testFail_NonAdminCannotAdjustRewardRate() public {
        vm.prank(USER_B);
        multiIncentiveModule.adjustRewardRate(aToken, incentiveToken1, 300);
    }

    function testFractionalRewardRates() public {
        // Admin sets a very small reward rate
        multiIncentiveModule.adjustRewardRate(aToken, incentiveToken1, 1); // 1 wei per second

        // User stakes
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));

        // Advance time by 1 day (86,400 seconds)
        vm.warp(block.timestamp + 1 days);

        // Calculate rewards
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = 
            multiIncentiveModule.previewEarned(address(this), aToken);

        // Expected reward is 86,400 wei
        assertEq(rewardAmounts[0], 86400);
        assertEq(rewardAmounts[1], 8640000);
    }

    function testNewIncentiveTokenAfter() public {

        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));

        vm.warp(block.timestamp + 4 weeks);

        address incentiveToken3 = address(0x5);

        multiIncentiveModule.addIncentiveReward(
            aToken,
            incentiveToken3,
            100
        );

        (address[] memory rewardTokens, uint256[] memory rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        assertEq(rewardamounts[2], 0);

        vm.warp(block.timestamp + 4 weeks);

        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);

        assertEq(rewardamounts[2], 241920000);

        
    }

    // edge case where there are no stakers
    function testNoRewardsWithoutStakers() public {
        // Ensure no users are staked
        uint256 totalStaked = multiIncentiveModule.multiTotalStaked(aToken);
        assertEq(totalStaked, 0);

        // Advance time by 1 week
        vm.warp(block.timestamp + 1 weeks);


        // Verify that reward per token remains zero
        uint256 rewardPerToken = multiIncentiveModule.multiRewardPerToken(aToken, incentiveToken1);
        assertEq(rewardPerToken, 0);

        // Verify that rewards for a user are zero
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = multiIncentiveModule.previewEarned(address(this), aToken);
        assertEq(rewardAmounts[0], 0);
        assertEq(rewardAmounts[1], 0);

        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));

        multiIncentiveModule.claimMultiRewards(aToken, address(this));

        // Verify that rewards are still zero
        // (rewardTokens, rewardAmounts) = multiIncentiveModule.previewEarned(address(this), aToken);
        // assertEq(rewardAmounts[0], 0);

    }

    function testManyUsersSameAmount() public {
        address USER_C = address(0x6);
        address USER_D = address(0x7);
        address USER_E = address(0x8);
        address USER_F = address(0x9);
        address USER_G = address(0x10);
        address USER_H = address(0x11);
        address USER_I = address(0x12);
        address USER_J = address(0x13);
        address USER_K = address(0x14);
        address USER_L = address(0x15);


        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, address(this));
        vm.prank(USER_C);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, USER_C);
        vm.prank(USER_D);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, USER_D);
        vm.prank(USER_E);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, USER_E);
        vm.prank(USER_F);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, USER_F);
        vm.prank(USER_G);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, USER_G);
        vm.prank(USER_H);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, USER_H);
        vm.prank(USER_I);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, USER_I);
        vm.prank(USER_J);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, USER_J);
        vm.prank(USER_K);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, USER_K);
        vm.prank(USER_L);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, USER_L);

        vm.warp(block.timestamp + 4 weeks + 1);

        (address[] memory rewardTokens, uint256[] memory rewardamounts) = multiIncentiveModule.previewEarned(address(this), aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_C, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_D, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_E, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_F, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_G, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_H, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_I, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_J, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_K, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_L, aToken);
        
    }

    function testManyUsersWithDifferentTimesAndAmounts() public {
        address USER_A = address(this);
        address USER_B = address(0x5);
        address USER_C = address(0x6);
        address USER_D = address(0x7);
        address USER_E = address(0x8);



        vm.warp(block.timestamp + 1 weeks);
        vm.prank(USER_A);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 0.5 ether, USER_A);

        vm.warp(block.timestamp + 1 weeks);
        vm.prank(USER_B);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1 ether, USER_B);

        vm.warp(block.timestamp + 1 weeks);
        vm.prank(USER_C);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1.5 ether, USER_C);

        vm.warp(block.timestamp + 1 weeks);
        vm.prank(USER_D);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 2 ether,USER_D);

        vm.warp(block.timestamp + 1 weeks);

        (address[] memory rewardTokens, uint256[] memory rewardamounts) = multiIncentiveModule.previewEarned(USER_A, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_B, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_C, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_D, aToken);


    }

    function testSimulation() public {
        address USER_A = address(this);
        address USER_B = address(0x5);

        vm.warp(block.timestamp + 2 hours);
        vm.prank(USER_A);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 531 ether, USER_A);

        vm.warp(block.timestamp + 1 hours);
        vm.prank(USER_B);
        multiIncentiveModule.stakeIncentiveTokens(aToken, 1027 ether, USER_B);

        vm.warp(block.timestamp + 1 weeks);
        vm.prank(USER_A);
        multiIncentiveModule.unstakeIncentiveTokens(aToken, 30 ether, USER_A);

        vm.warp(block.timestamp + 1 weeks);

        (address[] memory rewardTokens, uint256[] memory rewardamounts) = multiIncentiveModule.previewEarned(USER_A, aToken);
        (rewardTokens, rewardamounts) = multiIncentiveModule.previewEarned(USER_B, aToken);

    }


}