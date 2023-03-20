// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { Setup } from "./Setup.sol";
import { lveSECT } from "../lveSECT.sol";

import "hardhat/console.sol";

contract lveSectTest is Setup {
	function setUp() public {
		setupTests();
	}

	function testMintTo() public {
		// user1 mints 10 SECT tokens
		mintLveSectTo(user1, 10e18);
		assertEq(sect.balanceOf(address(lveSect)), 10e18);
		assertEq(lveSect.balanceOf(user1), 10e18);
	}

	function mintLveSectTo(address _to, uint256 _amount) public {
		// first allocate SECT to owner
		sect.allocate(self, _amount);
		// approve amnt
		sect.approve(address(lveSect), _amount);
		// mint to user
		lveSect.mintTo(_to, _amount);
	}

	function testSetPrice() public {
		// check that price cannot be set by non-owner
		vm.prank(user2);
		vm.expectRevert("Ownable: caller is not the owner");
		lveSect.setVeToken(address(veSect));

		// owner can set price
		lveSect.setVeToken(address(veSect));
		assertEq(address(lveSect.veSECT()), address(veSect));
	}

	function testConvertToLock() public {
		uint256 amnt = 10e18;
		mintLveSectTo(user1, amnt);

		lveSect.setVeToken(address(veSect));
		veSect.updateLockerWhitelist(address(lveSect), true);

		// user1 converts 10 SECT to veSECT
		vm.prank(user1);
		lveSect.convertToLock(amnt);

		assertEq(sect.balanceOf(address(lveSect)), 0);
		assertEq(lveSect.balanceOf(user1), 0);
		uint256 voteWeight = veSect.balanceOf(user1);
		// max lock is 2 years
		// 3 months is approx 1/8 of 2 years
		assertApproxEqRel(voteWeight, amnt / 8, .01e18);

		// test add to lock
		mintLveSectTo(user1, amnt);
		vm.prank(user1);
		lveSect.convertToLock(amnt);
		assertApproxEqRel(veSect.balanceOf(user1), voteWeight * 2, .0001e18);
	}

	function testConvertFail() public {
		uint256 amnt = 10e18;

		lveSect.setVeToken(address(veSect));
		veSect.updateLockerWhitelist(address(lveSect), true);

		mintLveSectTo(user1, amnt);

		lockSect(user1, amnt, 365 days);

		vm.prank(user1);
		vm.expectRevert("Only increase lock end");
		lveSect.convertToLock(amnt);
	}

	function testOnlyWhitelistedLocker() public {
		lveSect.setVeToken(address(veSect));
		lockSect(user1, 100e18, 7 days);

		// attacker should not be able to lock users tokens for longer
		vm.expectRevert("Only Whitelisted Locker");
		veSect.lockFor(user1, 1, block.timestamp + 2 * 364 days);
	}

	function testWhitelist() public {
		uint256 amnt = 10e18;
		mintLveSectTo(user1, amnt);

		lveSect.setVeToken(address(veSect));
		veSect.updateLockerWhitelist(address(lveSect), true);

		// user1 converts 10 SECT to veSECT
		vm.prank(user1);
		lveSect.convertToLock(amnt);

		// no longer works when not whitelisted
		mintLveSectTo(user1, amnt);

		veSect.updateLockerWhitelist(address(lveSect), false);
		vm.expectRevert("Only Whitelisted Locker");
		vm.prank(user1);
		lveSect.convertToLock(amnt);
	}

	function testIncreaseLockAmnt() public {
		uint256 amnt = 10e18;

		lveSect.setVeToken(address(veSect));
		mintLveSectTo(user1, amnt);

		lockSect(user1, amnt, 365 days);
		uint256 voteWeight = veSect.balanceOf(user1);

		vm.prank(user1);
		lveSect.addValueToLock(amnt);

		assertApproxEqRel(veSect.balanceOf(user1), voteWeight * 2, .0001e18);
	}

	function testIncreaseLockAmntFail() public {
		uint256 amnt = 10e18;

		lveSect.setVeToken(address(veSect));
		mintLveSectTo(user1, amnt);

		lockSect(user1, amnt, 10 days);
		uint256 voteWeight = veSect.balanceOf(user1);

		vm.prank(user1);
		vm.expectRevert(lveSECT.LockDurationTooShort.selector);
		lveSect.addValueToLock(amnt);
	}

	function lockSect(
		address user,
		uint256 amnt,
		uint256 duration
	) public {
		// first allocate SECT to user
		sect.allocate(user, amnt);
		vm.startPrank(user);
		sect.approve(address(veSect), amnt);
		// lock to user
		veSect.createLock(amnt, block.timestamp + duration);
		vm.stopPrank();
	}
}
