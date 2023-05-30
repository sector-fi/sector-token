// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IVotingEscrow } from "./interfaces/IVotingEscrow.sol";

// import "hardhat/console.sol";

/// @title liquid veSECT
/// @author @flashloner
/// @notice lveSECT is an ERC20 token that can be converted to a veSECT lock with a fixed lock duration
contract lveSECT is ERC20, Ownable {
	IERC20 public immutable sect;

	/// @dev veSECT token, set by owner after deployment
	IVotingEscrow public veSECT;
	/// @dev lock duration in seconds
	uint256 public immutable duration;

	/// @param sect_  address  address of the SECT token
	/// @param duration_  uint256  lock duration in seconds
	constructor(address sect_, uint256 duration_) ERC20("liquid veSECT", "lveSECT") {
		require(duration_ > 7 days, "duration must be longer than a week");
		require(duration_ < 2 * 365 days, "duration must shorter than 2 years");
		sect = IERC20(sect_);
		duration = duration_;
	}

	/// @notice sets the veSECT contract address
	/// @param veToken_  address  address of the veSECT contract
	function setVeToken(address veToken_) public onlyOwner {
		veSECT = IVotingEscrow(veToken_);
		sect.approve(veToken_, type(uint256).max);
		emit SetVeToken(address(veSECT));
	}

	/// @notice mints lveSECT to the recipient
	/// @param to  address  address of the recipient
	/// @param amount  uint256  amount to mint
	function mintTo(address to, uint256 amount) public {
		// sect is a known contract, so we can use transferFrom
		sect.transferFrom(msg.sender, address(this), amount);
		_mint(to, amount);
	}

	/// @notice converts lveSECT to a veSECT lock
	/// @dev existing lock time must be less than the new lock time and will be increased
	/// front-end UI should notify the user
	/// user must not have a delegated lock - UI should do a check
	/// @param amount uint256  amount to convert
	function convertToLock(uint256 amount) public {
		if (address(veSECT) == address(0)) revert veSECTNotSet();
		_burn(msg.sender, amount);
		uint256 expiry = block.timestamp + duration;
		veSECT.lockFor(msg.sender, amount, expiry);
		emit ConvertToLock(msg.sender, amount, expiry);
	}

	/// @notice use this method to add value to an existing lock
	/// @dev sender must have an existing veSECT balance
	/// and a lock with a longer duration than the new lock time
	/// if a user previously "quit" a lock with longer duration, they need to either:
	/// use a different account or create a a new lock with longer duration and at least 1 wei
	/// before calling this method
	/// @param amount uint256  amount to add to the lock
	function addValueToLock(uint256 amount) public {
		_burn(msg.sender, amount);
		uint256 expiry = block.timestamp + duration;
		uint256 lockEnd = veSECT.lockEnd(msg.sender);
		if (expiry > lockEnd) revert LockDurationTooShort();
		veSECT.increaseAmountFor(msg.sender, amount);
		emit AddValueToLock(msg.sender, amount);
	}

	event ConvertToLock(address indexed user, uint256 amount, uint256 duration);
	event AddValueToLock(address indexed user, uint256 amount);
	event SetVeToken(address indexed veToken);

	error veSECTNotSet();
	error LockDurationTooShort();
}
