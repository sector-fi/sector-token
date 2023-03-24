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

/// @notice This contract distributes 50% lveSECT and 50% bSECT tokens to users
/// it can be used to continuously distribute rewards to users
contract RewardDistributor is Ownable, IRewardDistributor {
	/// @dev Returns the token distributed by the contract
	IERC20 public immutable override token;
	IbSect public immutable override bToken;
	IveSect public immutable override lveToken;

	/// @dev The current merkle root of total claimable balances
	bytes32 public override merkleRoot;

	/// @dev The mapping that stores amounts already claimed by users
	mapping(address => uint256) public claimed;

	/// @param token_ The token to distribute
	/// @param bToken_ The bSECT token
	/// @param lveToken_ The lveSECT token
	/// @param merkleRoot_ The merkle root of the total claimable balances
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

	/// @notice Updates the merkle root - this can be used to increment total reward amounts
	/// @param newRoot The new merkle root
	function updateMerkleRoot(bytes32 newRoot) external onlyOwner {
		bytes32 oldRoot = merkleRoot;
		merkleRoot = newRoot;
		emit RootUpdated(oldRoot, newRoot);
	}

	/// @notice Claims the given amount of the token for the account. Reverts if the inputs are not a leaf in the tree
	/// @param account The account to claim for
	/// @param totalAmount The total amount of token to claim
	/// @param merkleProof The merkle proof of the claim
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
