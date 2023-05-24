// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { Setup } from "./Setup.sol";
import { MerkleUtils, TreeLeaf } from "./common/MerkleUtils.sol";

import "hardhat/console.sol";

contract GenericRewardDistributorTest is Setup, MerkleUtils {
	uint256 treeId = 0;

	function setUp() public {
		setupTests();
		sect.approve(address(lveSect), type(uint256).max);
	}

	function testClaim() public {
		TreeLeaf memory params = getParams(user1, treeId);
		genericDistributor.updateMerkleRoot(merkleRoots[treeId]);
		uint256 amnt = vm.parseUint(params.amount);
		lveSect.mintTo(address(genericDistributor), amnt);
		genericDistributor.claim(user1, amnt, params.proof);
		uint256 lveSectBal = lveSect.balanceOf(user1);
		assertEq(lveSectBal, amnt);
	}

	function testZeroRootShouldFail() public {
		TreeLeaf memory params = getParams(user1, treeId);
		uint256 amnt = vm.parseUint(params.amount);
		lveSect.mintTo(address(genericDistributor), amnt);

		vm.expectRevert("MerkleDistributor: No merkle root set");
		genericDistributor.claim(user1, amnt, params.proof);
	}

	function testTwoClaimIterations() public {
		TreeLeaf memory params = getParams(user1, treeId);
		genericDistributor.updateMerkleRoot(merkleRoots[treeId]);
		uint256 amnt = vm.parseUint(params.amount);
		lveSect.mintTo(address(genericDistributor), amnt);
		genericDistributor.claim(user1, amnt, params.proof);

		params = getParams(user1, 1);
		genericDistributor.updateMerkleRoot(merkleRoots[1]);

		uint256 newTotal = vm.parseUint(params.amount);
		lveSect.mintTo(address(genericDistributor), newTotal - amnt);
		genericDistributor.claim(user1, newTotal, params.proof);

		uint256 lveSectBal = lveSect.balanceOf(user1);
		assertEq(lveSectBal, newTotal);
	}
}
