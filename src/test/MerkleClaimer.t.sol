// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { Setup } from "./Setup.sol";
import { MerkleUtils, TreeLeaf } from "./common/MerkleUtils.sol";
import { MerkleClaimer, RewardClaim } from "../MerkleClaimer.sol";

import "hardhat/console.sol";

contract MerkleClaimerTest is Setup, MerkleUtils {
	MerkleClaimer merkleClaimer;

	function setUp() public {
		setupTests();
		sect.approve(address(lveSect), type(uint256).max);

		address[] memory merkleDistributors = new address[](2);
		merkleDistributors[0] = address(distributor);
		merkleDistributors[1] = address(genericDistributor);
		merkleClaimer = new MerkleClaimer(merkleDistributors);
	}

	function testClaim() public {
		// set up og distributor
		TreeLeaf memory params0 = getParams(user1, 0);
		distributor.updateMerkleRoot(merkleRoots[0]);

		uint256 amnt0 = vm.parseUint(params0.amount);
		sect.transfer(address(distributor), amnt0);

		// set up new distributor
		TreeLeaf memory params1 = getParams(user1, 1);
		genericDistributor.updateMerkleRoot(merkleRoots[1]);
		uint256 amnt1 = vm.parseUint(params1.amount);
		lveSect.mintTo(address(genericDistributor), amnt1);

		RewardClaim[] memory claims = new RewardClaim[](2);
		claims[0] = RewardClaim({
			distributor: address(distributor),
			amount: amnt0,
			proof: params0.proof
		});
		claims[1] = RewardClaim({
			distributor: address(genericDistributor),
			amount: amnt1,
			proof: params1.proof
		});

		merkleClaimer.claim(user1, claims);

		uint256 bSectBal = bSect.balanceOf(user1);
		uint256 lveSectBal = lveSect.balanceOf(user1);
		assertEq(bSectBal, amnt0 / 2);
		assertEq(lveSectBal, amnt0 / 2 + amnt1);
	}

	function testWhitelist() public {
		// set up new distributor
		TreeLeaf memory params1 = getParams(user1, 1);
		genericDistributor.updateMerkleRoot(merkleRoots[1]);
		uint256 amnt1 = vm.parseUint(params1.amount);
		lveSect.mintTo(address(genericDistributor), amnt1);

		RewardClaim[] memory claims = new RewardClaim[](1);
		claims[0] = RewardClaim({
			distributor: address(genericDistributor),
			amount: amnt1,
			proof: params1.proof
		});

		merkleClaimer.updateWhitelist(address(genericDistributor), false);

		vm.expectRevert(MerkleClaimer.NotWhitelisted.selector);
		merkleClaimer.claim(user1, claims);
	}
}
