// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { IVotingEscrow } from "./interfaces/IVotingEscrow.sol";

contract lveSECT is ERC20, Ownable {
	IERC20 public immutable sect;

	IVotingEscrow public veSECT;
	uint duration = 3 * 31 days;

	constructor(address sect_) ERC20("liquid veSECT", "lveSECT") {
		sect = IERC20(sect_);
	}

	function setVeToken(address veToken_) public onlyOwner {
		veSECT = IVotingEscrow(veToken_);
	}

	function mintTo(address to, uint256 amount) public {
		// sect is a known contract, so we can use transferFrom
		sect.transferFrom(msg.sender, address(this), amount);
		_mint(to, amount);
	}

	/// @notice existing lock time must be less than the new lock time and will be incrased
	/// front-end UI should notify the user
	function convertToLock(uint256 amount) public {
		_burn(msg.sender, amount);
		uint duration = block.timestamp + duration;
		veSECT.lockTo(msg.sender, amount, duration);
		emit ConvertToLock(msg.sender, amount, duration);
	}

	/// @dev sender must have an existing veSECT balance
	function addValueToLock(uint256 amount) public {
		_burn(msg.sender, amount);
		// TODO handle this logic
		// veSECT.lockTo(msg.sender, amount, block.timestamp + duration);
		emit AddValueToLock(msg.sender, amount);
	}

	event ConvertToLock(address indexed user, uint256 amount, uint256 duration);
	event AddValueToLock(address indexed user, uint256 amount);
}
