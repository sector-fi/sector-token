// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { Setup } from "./Setup.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import "forge-std/StdJson.sol";

import "hardhat/console.sol";

contract RewardDistributorTest is Setup {
	using stdJson for string;

	struct TreeLeaf {
		string amount;
		uint256 index;
		bytes32[] proof;
	}

	bytes32 merkleRoot;

	function getParams(address account, uint256 treeId) public returns (TreeLeaf memory params) {
		string memory addrString = Strings.toHexString(uint160(account), 20);

		string memory root = vm.projectRoot();
		string memory path = treeId == 0
			? string.concat(root, "/scripts/treeJSON.json")
			: string.concat(root, "/scripts/treeJSON2.json");
		string memory json = vm.readFile(path);

		bytes memory merkleRootB = json.parseRaw(".root");
		merkleRoot = abi.decode(merkleRootB, (bytes32));

		bytes memory paramsBytes = json.parseRaw(string.concat(".", addrString));
		params = abi.decode(paramsBytes, (TreeLeaf));
	}

	function setUp() public {
		setupTests();
	}

	function testClaim() public {
		TreeLeaf memory params = getParams(user1, 0);
		distributor.updateMerkleRoot(merkleRoot);
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
		distributor.updateMerkleRoot(merkleRoot);
		uint256 amnt = vm.parseUint(params.amount);
		sect.transfer(address(distributor), amnt);
		distributor.claim(user1, amnt, params.proof);

		params = getParams(user1, 1);
		distributor.updateMerkleRoot(merkleRoot);

		uint256 newTotal = vm.parseUint(params.amount);
		sect.transfer(address(distributor), newTotal - amnt);
		distributor.claim(user1, newTotal, params.proof);

		uint256 bSectBal = bSect.balanceOf(user1);
		uint256 lveSectBal = lveSect.balanceOf(user1);
		assertEq(bSectBal, newTotal / 2);
		assertEq(lveSectBal, newTotal / 2);
	}
}
