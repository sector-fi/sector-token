// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { Test } from "forge-std/Test.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract SectorTest is Test {
	address owner = address(this);
	address self = address(this);

	address user1 = address(1);
	address user2 = address(2);
	address user3 = address(3);

	function _accessErrorString(
		bytes32 role,
		address account
	) internal pure returns (bytes memory) {
		return
			bytes(
				abi.encodePacked(
					"AccessControl: account ",
					Strings.toHexString(uint160(account), 20),
					" is missing role ",
					Strings.toHexString(uint256(role), 32)
				)
			);
	}
}
