// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { Setup } from "./Setup.sol";
import { lveSECT } from "../lveSECT.sol";
import { ProtocolRewards } from "../ProtocolRewards.sol";

import { MockERC20 } from "./MockERC20.sol";

import "hardhat/console.sol";

contract ProtocolRewardsTest is Setup {
	ProtocolRewards usdcRewards;
	ProtocolRewards ethRewards;

	MockERC20 usdc;
	MockERC20 weth;

	uint256 usdcAmnt;
	uint256 ethAmnt;

	function setUp() public {
		setupTests();
		usdc = new MockERC20("USDC", "USDC", 6);
		weth = new MockERC20("WETH", "WETH", 18);

		usdcRewards = new ProtocolRewards(address(veSect), self, address(usdc));
		ethRewards = new ProtocolRewards(address(veSect), self, address(weth));

		/// test timestamp starts at 0
		skip(14 days);
	}

	function addRewardRound() public {
		// add block number to count prev locks
		vm.roll(block.number + 1);

		usdcAmnt = 1000e6;
		deal(address(usdc), address(usdcRewards), usdcAmnt);

		usdcRewards.addRewardRound();

		ethAmnt = 1e18;
		deal(address(weth), address(ethRewards), ethAmnt);

		ethRewards.addRewardRound();
	}

	function createLock(
		address user,
		uint256 amnt,
		uint256 duration
	) public {
		vm.startPrank(user);
		deal(address(sect), user, amnt);
		sect.approve(address(veSect), amnt);
		veSect.createLock(amnt, block.timestamp + duration);
		vm.roll(block.number + 1);
		vm.stopPrank();
	}

	function testReward() public {
		uint256 amnt = 1e18;

		createLock(user1, amnt, 3 * 30 days);
		createLock(user2, amnt, 6 * 30 days);

		addRewardRound();
		vm.roll(block.number + 10000);
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

		// claiming 10 years worth of rewards will cost
		// 3,261,355 gas (about 1/10th of block limit)
		uint256 rewardAmnt = 1e6;
		uint256 i;
		for (i; i < 279; i++) {
			createLock(user1, amnt, 30 days);
			deal(address(usdc), self, rewardAmnt);
			usdc.transfer(address(usdcRewards), rewardAmnt);
			skip(14 days);
			usdcRewards.addRewardRound();
		}

		startMeasuringGas("getReward");
		vm.prank(user1);
		usdcRewards.getReward();
		stopMeasuringGas();

		assertEq(usdcRewards.firstUnclaimedReward(user1), usdcRewards.getTotalRewards());
		assertEq(usdc.balanceOf(user1), usdcAmnt + rewardAmnt * i);
	}

	function testMultipleClaims() public {
		uint256 amnt = 1e18;

		createLock(user1, amnt, 10 * 30 days);

		for (uint256 i; i < 10; i++) {
			uint256 amnt = 1e6;
			deal(address(usdc), self, amnt);
			deal(address(usdc), address(usdcRewards), amnt);

			skip(14 days);
			usdcRewards.addRewardRound();

			vm.prank(user1);
			usdcRewards.getReward();
			assertEq(usdc.balanceOf(user1), usdcAmnt + amnt * (i + 1));

			assertEq(usdcRewards.firstUnclaimedReward(user1), usdcRewards.getTotalRewards());
		}
	}

	function teset_attack_vector() public {
		// create initial user lock
		uint256 amnt = 1e18;
		vm.startPrank(address(999));
		deal(address(sect), address(999), amnt);
		sect.approve(address(veSect), amnt);
		veSect.createLock(amnt, block.timestamp + 3 * 30 days);
		vm.roll(block.number + 1);
		vm.stopPrank();

		// deposit some rewards
		uint256 initial_rewards = 73503 ether;
		deal(address(weth), address(ethRewards), initial_rewards);
		ethRewards.addRewardRound();
		vm.roll(block.number + 1);
		vm.warp(block.timestamp + 2 weeks);

		//	start test
		uint256 pr_balance = weth.balanceOf(address(ethRewards));

		deal(address(sect), address(this), 260_000 ether + 19 wei);
		sect.approve(address(veSect), type(uint256).max);
		veSect.createLock(260_000 ether, block.timestamp + 100 weeks);

		uint256 ve_balance = veSect.balanceOfAt(address(this), block.number);
		uint256 ve_supply = veSect.totalSupplyAt(block.number);
		uint256 ratio = (20 * ve_balance * 1e18) / ve_supply;
		console.log("ratio: %d SECT", ratio / 1 ether);
		uint256 needed = (pr_balance * 1e18) / (ratio - 1e18) - 1 gwei;

		console.log("Needed: %d SECT", needed);
		// deal(address(weth), address(ethRewards), needed);
		deal(address(weth), address(self), needed);
		weth.transfer(address(ethRewards), needed);
		ethRewards.addRewardRound();

		console.log("[+] Start state:");
		pr_balance = weth.balanceOf(address(ethRewards));
		console.log(" -  ProtocolRewards balance: %d SECT\n", pr_balance / 1 ether);

		ethRewards.getReward();

		for (uint160 i = 1; i <= 19; i++) {
			deal(address(sect), address(i), 1 wei);
			vm.prank(address(i));
			sect.approve(address(veSect), type(uint256).max);
			vm.prank(address(i));
			veSect.createLock(1 wei, block.timestamp + 100 weeks);
			veSect.delegate(address(i));
			vm.prank(address(i));
			ethRewards.getReward();
		}

		pr_balance = weth.balanceOf(address(ethRewards));
		assertEq(pr_balance, initial_rewards + needed);
		console.log("[+] Final state:");
		console.log(" -  ProtocolRewards balance: %d SECT", pr_balance / 1 ether);
	}
}
