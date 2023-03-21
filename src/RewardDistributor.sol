// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

// partially inspired by
// https://github.com/Gearbox-protocol/rewards/blob/master/contracts/AirdropDistributor.sol

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IRewardDistributor } from "./interfaces/IRewardDistributor.sol";
import { IbSect, IveSect } from "./interfaces/ITokens.sol";

// import "hardhat/console.sol";

contract RewardDistributor is Ownable, IRewardDistributor {
	/// @dev Returns the token distributed by the contract
	IERC20 public immutable override token;
	IbSect public immutable override bToken;
	IveSect public immutable override lveToken;

	/// @dev The current merkle root of total claimable balances
	bytes32 public override merkleRoot;

	/// @dev The mapping that stores amounts already claimed by users
	mapping(address => uint256) public claimed;

	constructor(
		address token_,
		address bToken_,
		address lveToken_,
		bytes32 merkleRoot_
	) {
		token = IERC20(token_);
		bToken = IbSect(bToken_);
		lveToken = IveSect(lveToken_);
		merkleRoot = merkleRoot_;
		token.approve(bToken_, type(uint256).max);
		token.approve(lveToken_, type(uint256).max);
	}

	function updateMerkleRoot(bytes32 newRoot) external onlyOwner {
		bytes32 oldRoot = merkleRoot;
		merkleRoot = newRoot;
		emit RootUpdated(oldRoot, newRoot);
	}

	function claim(
		address account,
		uint256 totalAmount,
		bytes32[] calldata merkleProof
	) external override {
		require(merkleRoot != bytes32(0), "MerkleDistributor: No merkle root set");
		require(claimed[account] < totalAmount, "MerkleDistributor: Nothing to claim");

		bytes32 node = keccak256(bytes.concat(keccak256(abi.encode(account, totalAmount))));

		require(
			MerkleProof.verify(merkleProof, merkleRoot, node),
			"MerkleDistributor: Invalid proof."
		);

		uint256 claimedAmount = totalAmount - claimed[account];
		claimed[account] += claimedAmount;

		uint256 bTokenAmount = claimedAmount / 2;
		uint256 lveTokenAmount = claimedAmount - bTokenAmount;
		bToken.mintTo(account, bTokenAmount);
		lveToken.mintTo(account, lveTokenAmount);

		emit Claimed(account, claimedAmount, false);
	}
}
