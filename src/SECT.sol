// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SECT is ERC20, Ownable {
	constructor() ERC20("Sector", "SECT") {
		// mint 100 million tokens to the contract
		_mint(address(this), 100000000e18);
	}

	/// @dev owner can allocate tokens to a user
	function allocate(address to_, uint256 amount_) public onlyOwner {
		_transfer(address(this), to_, amount_);
	}

	/// @notice Burn tokens
	/// @param  _amount  uint256  Amount to burn
	function burn(uint256 _amount) external {
		_burn(msg.sender, _amount);
	}
}
