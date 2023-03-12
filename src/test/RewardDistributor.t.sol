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

	function getParams(address account) public returns (TreeLeaf memory params) {
		string memory addrString = Strings.toHexString(uint160(account), 20);

		string memory root = vm.projectRoot();
		string memory path = string.concat(root, "/scripts/treeJSON.json");
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
		TreeLeaf memory params = getParams(user1);
		distributor.updateMerkleRoot(merkleRoot);
		uint amnt = vm.parseUint(params.amount);
		sect.allocate(address(distributor), amnt);
		distributor.claim(params.index, user1, amnt, params.proof);
		uint bSectBal = bSect.balanceOf(user1);
		uint lveSectBal = lveSect.balanceOf(user1);
		assertEq(bSectBal, amnt / 2);
		assertEq(lveSectBal, amnt / 2);
	}
}
