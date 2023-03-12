// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract bSECT is ERC20, Ownable {
	using SafeERC20 for IERC20;

	IERC20 public immutable SECT;

	IERC20 immutable underlying;

	// price per 1e18 SECT that a holder must pay to convert to sect token
	uint public price;

	constructor(address SECT_, address underlying_) ERC20("bSECT", "bSECT") {
		SECT = IERC20(SECT_);
		underlying = IERC20(underlying_);
	}

	/// @dev price must be set immediately upon liquidity deployment
	function setPrice(uint price_) public onlyOwner {
		price = price_;
		emit SetPrice(price_);
	}

	function mintTo(address to, uint256 amount) public {
		// sect is a known contract, so we can use transferFrom
		SECT.transferFrom(msg.sender, address(this), amount);
		_mint(to, amount);
	}

	function convert(uint256 amount) public {
		if (price == 0) revert PriceNotSet();
		_burn(msg.sender, amount);
		uint num = amount * price;
		// round up to avoid griefing
		uint underlyingAmnt = num / 1e18 + (num % 1e18 > 0 ? 1 : 0);
		underlying.safeTransferFrom(msg.sender, address(this), underlyingAmnt);
		SECT.transfer(msg.sender, amount);
		emit Convert(msg.sender, amount);
	}

	function claimUnderlying(address to) public onlyOwner {
		underlying.safeTransfer(to, underlying.balanceOf(address(this)));
	}

	event SetPrice(uint price);
	event Convert(address indexed user, uint256 amount);

	error PriceNotSet();
}
