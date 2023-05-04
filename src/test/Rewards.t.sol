// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { Setup } from "./Setup.sol";
import { lveSECT } from "../lveSECT.sol";
import { Rewards } from "../Rewards.sol";

import { MockERC20 } from "./MockERC20.sol";

import "hardhat/console.sol";

contract RewardsTest is Setup {
	Rewards usdcRewards;
	Rewards ethRewards;

	MockERC20 usdc;
	MockERC20 weth;

	uint256 usdcAmnt;
	uint256 ethAmnt;

	function setUp() public {
		setupTests();
		usdc = new MockERC20("USDC", "USDC", 6);
		weth = new MockERC20("WETH", "WETH", 18);

		usdcRewards = new Rewards(self, address(veSect), self, address(usdc));
		ethRewards = new Rewards(self, address(veSect), self, address(weth));

		deal(address(sect), user1, 1e18);
		sect.approve(address(veSect), 1e18);
		veSect.createLock(1e18, block.timestamp + 7 days);

		/// test timestamp starts at 0
		skip(14 days);

		usdcAmnt = 1000e6;
		deal(address(usdc), address(usdcRewards), usdcAmnt);
		usdcRewards.addRewardRound();

		ethAmnt = 1e18;
		deal(address(weth), address(ethRewards), ethAmnt);
		ethRewards.addRewardRound();
	}

	function testReward() public {
		uint256 amnt = 1e18;

		vm.startPrank(user1);
		deal(address(sect), user1, amnt);
		sect.approve(address(veSect), amnt);
		veSect.createLock(amnt, block.timestamp + 3 * 30 days);
		vm.stopPrank();

		vm.startPrank(user2);
		deal(address(sect), user2, amnt);
		sect.approve(address(veSect), amnt);
		veSect.createLock(amnt, block.timestamp + 6 * 30 days);
		vm.stopPrank();

		skip(3 * 31 days);

		uint256 u1Earned = usdcRewards.earned(user1);
		uint256 u2Earned = usdcRewards.earned(user2);

		assertApproxEqRel(u1Earned, usdcAmnt / 3, .03e18);
		assertApproxEqRel(u2Earned, (usdcAmnt * 2) / 3, .03e18);

		vm.prank(user1);
		usdcRewards.getReward();
		assertEq(usdc.balanceOf(user1), u1Earned);

		/// should not be able to claim again
		vm.prank(user1);
		usdcRewards.getReward();
		assertEq(usdc.balanceOf(user1), u1Earned);

		vm.prank(user2);
		usdcRewards.getReward();
		assertEq(usdc.balanceOf(user2), u2Earned);
	}

	function testMaxRounds() public {
		uint256 amnt = 1e18;

		vm.startPrank(user1);
		deal(address(sect), user1, amnt);
		sect.approve(address(veSect), amnt);
		veSect.createLock(amnt, block.timestamp + 3 * 30 days);
		vm.stopPrank();

		// claiming 10 years worth of rewards will cost
		// 3,261,355 gas (about 1/10th of block limit)
		for (uint256 i = 0; i < 279; i++) {
			uint256 amnt = 1e6;
			deal(address(usdc), self, amnt);
			usdc.transfer(address(usdcRewards), amnt);
			skip(14 days);
			usdcRewards.addRewardRound();
		}

		startMeasuringGas("getReward");
		vm.prank(user1);
		usdcRewards.getReward();
		stopMeasuringGas();
	}

	function testMultipleClaims() public {
		uint256 amnt = 1e18;

		vm.startPrank(user1);
		deal(address(sect), user1, amnt);
		sect.approve(address(veSect), amnt);
		veSect.createLock(amnt, block.timestamp + 3 * 30 days);
		vm.stopPrank();

		for (uint256 i = 0; i < 10; i++) {
			uint256 amnt = 1e6;
			deal(address(usdc), self, amnt);
			usdc.transfer(address(usdcRewards), amnt);

			skip(14 days);
			usdcRewards.addRewardRound();

			vm.prank(user1);
			usdcRewards.getReward();
			assertEq(usdc.balanceOf(user1), usdcAmnt + amnt * (i + 1));
		}
	}
}
