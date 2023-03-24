// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { Setup } from "./Setup.sol";
import { DisbursementCliff, IERC20 } from "../DisbursementCliff.sol";

contract DisbursementCliffTest is Setup {
	DisbursementCliff vesting;

	function setUp() public {
		setupTests();
		// start data is 4 months from start to make sure cliff is 10% of total
		// and rest of vest is linear
		uint256 startDate = block.timestamp + 121 days; // 4 months
		uint256 cliffDate = block.timestamp + 182 days; // 6 months
		uint256 disbursementPeriod = 2 * 365 days - 121 days;
		vesting = new DisbursementCliff(
			user1,
			self,
			disbursementPeriod,
			startDate,
			cliffDate,
			IERC20(sect)
		);
		sect.transfer(address(vesting), 100e18);
	}

	function testCliff() public {
		uint256 zero = vesting.calcMaxWithdraw();
		assertEq(zero, 0);
		skip(121 days);
		zero = vesting.calcMaxWithdraw();
		assertEq(zero, 0);

		skip(61 days);
		uint256 ten = vesting.calcMaxWithdraw();
		assertApproxEqRel(ten, 10e18, .01e18, "should unlock 10%");

		vm.prank(user1);
		vm.expectRevert("Tokens are locked");
		vesting.withdraw(user1, ten);

		vesting.unlock();
		vm.prank(user1);
		vesting.withdraw(user1, ten);
		assertEq(sect.balanceOf(user1), ten);
	}

	function testVest() public {
		uint256 disbursementPeriod = 2 * 365 days - 121 days;
		skip(120 days + disbursementPeriod / 2);
		uint256 half = vesting.calcMaxWithdraw();
		assertApproxEqRel(half, 50e18, .01e18, "should unlock 50%");

		vesting.unlock();
		vm.prank(user1);
		vesting.withdraw(user1, half);
		assertEq(sect.balanceOf(user1), half);
	}
}