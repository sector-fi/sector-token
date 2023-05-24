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
import { GenericRewardDistributor } from "../GenericRewardDistributor.sol";

contract Setup is SectorTest {
	SECT sect;
	lveSECT lveSect;
	bSECT bSect;
	VotingEscrow veSect;
	RewardDistributor distributor;
	GenericRewardDistributor genericDistributor;
	MockERC20 underlying;

	string private checkpointLabel;
	uint256 private checkpointGasLeft = 1; // Start the slot warm.

	function setupTests() public {
		sect = new SECT();
		underlying = new MockERC20("USDC", "USDC", 6);
		lveSect = new lveSECT(address(sect), 91 days); // 3 month lock duration
		bSect = new bSECT(address(sect), address(underlying));
		veSect = new VotingEscrow(owner, self, address(sect), "veSECT", "veSECT");
		distributor = new RewardDistributor(
			address(sect),
			address(lveSect),
			address(bSect),
			bytes32(0)
		);
		genericDistributor = new GenericRewardDistributor(address(lveSect), bytes32(0));
	}

	function startMeasuringGas(string memory label) internal virtual {
		checkpointLabel = label;

		checkpointGasLeft = gasleft();
	}

	function stopMeasuringGas() internal virtual {
		uint256 checkpointGasLeft2 = gasleft();

		// Subtract 100 to account for the warm SLOAD in startMeasuringGas.
		uint256 gasDelta = checkpointGasLeft - checkpointGasLeft2 - 100;

		emit log_named_uint(string(abi.encodePacked(checkpointLabel, " Gas")), gasDelta);
	}
}
