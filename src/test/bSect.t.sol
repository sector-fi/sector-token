// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { Setup } from "./Setup.sol";

import "hardhat/console.sol";

contract bSectTest is Setup {
	uint private price = 2e6; // 2 USDC per 1 SECT

	function setUp() public {
		setupTests();
		bSect.setPrice(price);
	}

	function testMintTo() public {
		// user1 mints 10 SECT tokens
		mintBSectTo(user1, 10e18);
		assertEq(sect.balanceOf(address(bSect)), 10e18);
		assertEq(bSect.balanceOf(user1), 10e18);
	}

	function testConvert() public {
		mintBSectTo(user1, 10e18);
		// user1 converts her bSECT tokens to underlying tokens
		vm.startPrank(user1);
		underlying.mint(user1, 20e6);
		underlying.approve(address(bSect), 20e6);
		bSect.convert(10e18);
		vm.stopPrank();

		assertEq(bSect.balanceOf(user1), 0);
		assertEq(underlying.balanceOf(address(bSect)), 20e6);
		assertEq(sect.balanceOf(user1), 10e18); // there is a small rounding error here
	}

	function testSetPrice() public {
		// check that price cannot be set by non-owner
		vm.prank(user2);
		vm.expectRevert("Ownable: caller is not the owner");
		bSect.setPrice(price);

		// owner can set price
		bSect.setPrice(price);
		assertEq(bSect.price(), price);
	}

	function testRoundingFuzz(uint x) public {
		uint amnt = bound(x, 1, .5e12);
		mintBSectTo(user1, amnt);

		// check that minimum amount is enforced
		underlying.mint(user1, 1);
		vm.startPrank(user1);
		underlying.approve(address(bSect), 1);
		bSect.convert(amnt);
		vm.stopPrank();

		assertEq(sect.balanceOf(user1), amnt);
		assertEq(bSect.balanceOf(user1), 0);
		assertEq(underlying.balanceOf(address(bSect)), 1);
		assertEq(underlying.balanceOf(user1), 0);
	}

	function mintBSectTo(address _to, uint _amount) public {
		// first allocate SECT to owner
		sect.allocate(self, _amount);
		// approve amnt
		sect.approve(address(bSect), _amount);
		// mint to user
		bSect.mintTo(_to, _amount);
	}
}
