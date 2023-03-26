// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title bSECT token
/// @author @flashloner
/// @notice bSECT is a token that can be converted to SECT for a fixed price denominated in underlying
contract bSECT is ERC20, Ownable {
	using SafeERC20 for IERC20;

	/// @dev SECT token
	IERC20 public immutable SECT;

	/// @dev underlying token required to convert bSECT to SECT
	IERC20 public immutable underlying;

	// price per 1e18 SECT that a holder must pay to convert to sect token
	uint256 public price;

	/// @notice Construct a new bSECT token
	/// @param SECT_ SECT token address
	/// @param underlying_ Underlying token address
	constructor(address SECT_, address underlying_) ERC20("bSECT", "bSECT") {
		SECT = IERC20(SECT_);
		underlying = IERC20(underlying_);
	}

	/// @notice Set price per 1e18 SECT that a holder must pay to convert to sect token
	/// @dev price must be set immediately upon liquidity deployment
	/// @param price_ Price per 1e18 SECT that a holder must pay to convert to sect token
	function setPrice(uint256 price_) public onlyOwner {
		price = price_;
		emit SetPrice(price_);
	}

	/// @notice Mint bSECT to an account
	/// @param to Account to mint to
	/// @param amount Amount to mint
	function mintTo(address to, uint256 amount) public {
		// sect is a known contract, so we can use transferFrom
		SECT.transferFrom(msg.sender, address(this), amount);
		_mint(to, amount);
	}

	/// @notice Convert bSECT to SECT for a price denominated in underlying
	/// @param amount Amount of bSECT to convert
	function convert(uint256 amount) public {
		if (price == 0) revert PriceNotSet();
		_burn(msg.sender, amount);
		uint256 num = amount * price;
		// round up to avoid griefing
		uint256 underlyingAmnt = num / 1e18 + (num % 1e18 > 0 ? 1 : 0);
		underlying.safeTransferFrom(msg.sender, address(this), underlyingAmnt);
		SECT.transfer(msg.sender, amount);
		emit Convert(msg.sender, amount);
	}

	/// @notice owner can claim underlying tokens
	function claimUnderlying(address to) public onlyOwner {
		underlying.safeTransfer(to, underlying.balanceOf(address(this)));
	}

	event SetPrice(uint256 price);
	event Convert(address indexed user, uint256 amount);

	error PriceNotSet();
}
