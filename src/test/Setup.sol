// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "./MockERC20.sol";
import { SectorTest } from "./SectorTest.sol";
import { SECT } from "../SECT.sol";
import { lveSECT } from "../lveSECT.sol";
import { bSECT } from "../bSECT.sol";
import { VotingEscrow } from "../VotingEscrow.sol";
import { RewardDistributor } from "../RewardDistributor.sol";

contract Setup is SectorTest {
	SECT sect;
	lveSECT lveSect;
	bSECT bSect;
	VotingEscrow veSect;
	RewardDistributor distributor;
	MockERC20 underlying;

	function setupTests() public {
		sect = new SECT();
		underlying = new MockERC20("USDC", "USDC", 6);
		lveSect = new lveSECT(address(sect));
		bSect = new bSECT(address(sect), address(underlying));
		veSect = new VotingEscrow(owner, self, address(sect), "veSECT", "veSECT");
		distributor = new RewardDistributor(
			address(sect),
			address(lveSect),
			address(bSect),
			bytes32(0)
		);
	}
}
