// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Test } from "forge-std/Test.sol";

import "forge-std/StdJson.sol";

struct TreeLeaf {
	string amount;
	uint256 index;
	bytes32[] proof;
}

contract MerkleUtils is Test {
	using stdJson for string;

	mapping(uint256 => bytes32) merkleRoots;

	function getParams(address account, uint256 treeId) public returns (TreeLeaf memory params) {
		string memory addrString = Strings.toHexString(uint160(account), 20);

		string memory root = vm.projectRoot();
		string memory path = treeId == 0
			? string.concat(root, "/scripts/treeJSON.json")
			: string.concat(root, "/scripts/treeJSON2.json");
		string memory json = vm.readFile(path);

		bytes memory merkleRoot = json.parseRaw(".root");
		merkleRoots[treeId] = abi.decode(merkleRoot, (bytes32));

		bytes memory paramsBytes = json.parseRaw(string.concat(".", addrString));
		params = abi.decode(paramsBytes, (TreeLeaf));
	}
}
