// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Sector Token
/// @dev max supply is immediately minted to deployer to deposit into a governance multisig
contract SECT is ERC20 {
	uint256 public constant MAX_SUPPLY = 100000000e18; /// 100,000,000 SECT

	constructor() ERC20("Sector", "SECT") {
		// mint max supply to deployer
		_mint(msg.sender, MAX_SUPPLY);
	}

	/// @notice Burn tokens
	/// @param  _amount  uint256  Amount to burn
	function burn(uint256 _amount) external {
		_burn(msg.sender, _amount);
	}
}
