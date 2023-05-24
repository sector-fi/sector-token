// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { Setup } from "./Setup.sol";
import { MerkleUtils, TreeLeaf } from "./common/MerkleUtils.sol";

import "hardhat/console.sol";

contract RewardDistributorTest is Setup, MerkleUtils {
	function setUp() public {
		setupTests();
	}

	function testClaim() public {
		TreeLeaf memory params = getParams(user1, 0);
		distributor.updateMerkleRoot(merkleRoots[0]);
		uint256 amnt = vm.parseUint(params.amount);
		sect.transfer(address(distributor), amnt);
		distributor.claim(user1, amnt, params.proof);
		uint256 bSectBal = bSect.balanceOf(user1);
		uint256 lveSectBal = lveSect.balanceOf(user1);
		assertEq(bSectBal, amnt / 2);
		assertEq(lveSectBal, amnt / 2);
	}

	function testZeroRootShouldFail() public {
		TreeLeaf memory params = getParams(user1, 0);
		uint256 amnt = vm.parseUint(params.amount);
		sect.transfer(address(distributor), amnt);
		vm.expectRevert("MerkleDistributor: No merkle root set");
		distributor.claim(user1, amnt, params.proof);
	}

	function testTwoClaimIterations() public {
		TreeLeaf memory params = getParams(user1, 0);
		distributor.updateMerkleRoot(merkleRoots[0]);
		uint256 amnt = vm.parseUint(params.amount);
		sect.transfer(address(distributor), amnt);
		distributor.claim(user1, amnt, params.proof);

		params = getParams(user1, 1);
		distributor.updateMerkleRoot(merkleRoots[1]);

		uint256 newTotal = vm.parseUint(params.amount);
		sect.transfer(address(distributor), newTotal - amnt);
		distributor.claim(user1, newTotal, params.proof);

		uint256 bSectBal = bSect.balanceOf(user1);
		uint256 lveSectBal = lveSect.balanceOf(user1);
		assertEq(bSectBal, newTotal / 2);
		assertEq(lveSectBal, newTotal / 2);
	}
}
