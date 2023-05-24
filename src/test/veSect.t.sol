// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { Setup } from "./Setup.sol";

import "hardhat/console.sol";

contract veSectTest is Setup {
	function setUp() public {
		setupTests();
	}

	function testQuit() public {
		uint256 amnt = 10000;
		// approve amnt
		sect.approve(address(veSect), amnt);
		veSect.createLock(amnt, block.timestamp + 3 * 30 days);

		// try to quit
		vm.expectRevert("Quit disabled");
		veSect.quitLock();

		veSect.setQuitEnabled(true);
		assertEq(veSect.quitEnabled(), true);

		// should not fail
		veSect.quitLock();

		veSect.setQuitEnabled(false);
		assertEq(veSect.quitEnabled(), false);
	}

	function testEnableQuitPermissions() public {
		vm.prank(user2);
		vm.expectRevert("Only owner");
		veSect.setQuitEnabled(true);
	}

	function testDelegate() public {
		uint256 amnt = 1e18;
		// approve amnt
		sect.approve(address(veSect), amnt);
		veSect.createLock(amnt, block.timestamp + 182 days);

		sect.transfer(user2, amnt);
		vm.startPrank(user2);
		sect.approve(address(veSect), amnt);
		veSect.createLock(amnt, block.timestamp + 182 days);
		vm.stopPrank();

		veSect.delegate(user2);
		uint256 selfBalance = veSect.balanceOf(self);
		uint256 user2Balance = veSect.balanceOf(user2);

		console.log("self", selfBalance);
		console.log("user2", user2Balance);

		assertEq(selfBalance, 0);
		assertApproxEqRel(user2Balance, (amnt * 2) / 4, .01e18);

		sect.transfer(user2, amnt);
		vm.startPrank(user2);
		sect.approve(address(veSect), amnt);
		veSect.createLock(amnt, block.timestamp + 182 days);
		vm.stopPrank();

		selfBalance = veSect.balanceOf(self);
		user2Balance = veSect.balanceOf(user2);

		console.log("self", selfBalance);
		console.log("user2", user2Balance);

		sect.approve(address(veSect), amnt);
		vm.expectRevert("Delegated lock");
		veSect.createLock(amnt, block.timestamp + 182 days);
	}
}
