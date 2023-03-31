// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { Setup } from "./Setup.sol";
import { lveSECT } from "../lveSECT.sol";

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
}
