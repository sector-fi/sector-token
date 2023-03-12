// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { IVotingEscrow } from "./interfaces/IVotingEscrow.sol";

import "hardhat/console.sol";

contract lveSECT is ERC20, Ownable {
	IERC20 public immutable sect;

	IVotingEscrow public veSECT;
	uint duration = 182 days; // ~6 months

	constructor(address sect_) ERC20("liquid veSECT", "lveSECT") {
		sect = IERC20(sect_);
	}

	function setVeToken(address veToken_) public onlyOwner {
		veSECT = IVotingEscrow(veToken_);
		sect.approve(veToken_, type(uint256).max);
		emit SetVeToken(address(veSECT));
	}

	function mintTo(address to, uint256 amount) public {
		// sect is a known contract, so we can use transferFrom
		sect.transferFrom(msg.sender, address(this), amount);
		_mint(to, amount);
	}

	/// @notice existing lock time must be less than the new lock time and will be incrased
	/// front-end UI should notify the user
	function convertToLock(uint256 amount) public {
		if (address(veSECT) == address(0)) revert veSECTNotSet();
		_burn(msg.sender, amount);
		uint duration = block.timestamp + duration;
		veSECT.lockFor(msg.sender, amount, duration);
		emit ConvertToLock(msg.sender, amount, duration);
	}

	/// @dev sender must have an existing veSECT balance
	function addValueToLock(uint256 amount) public {
		_burn(msg.sender, amount);
		veSECT.increaseAmountFor(msg.sender, amount);
		emit AddValueToLock(msg.sender, amount);
	}

	event ConvertToLock(address indexed user, uint256 amount, uint256 duration);
	event AddValueToLock(address indexed user, uint256 amount);
	event SetVeToken(address indexed veToken);

	error veSECTNotSet();
}
