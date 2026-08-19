// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title QBitFlow Test Token (QBFT)
 * @notice Testnet-only ERC20 used as the single canonical token in QBitFlow's test mode.
 *         6 decimals to match USDC/USDT/EURC. Unlimited mint by owner (faucet).
 *         Governance rotation (owner, cosigner) requires an EIP-712 signature from the
 *         current cosigner, replay-protected by a per-signer nonce.
 */
contract QBFT is ERC20, EIP712 {
	// ---------------------------------------------------------------------
	// Errors
	// ---------------------------------------------------------------------
	error NotOwner();
	error InvalidAddress();
	error InvalidSignature();
	error InvalidNonce();

	// ---------------------------------------------------------------------
	// Events
	// ---------------------------------------------------------------------
	event OwnerUpdated(address indexed previousOwner, address indexed newOwner);
	event CosignerUpdated(address indexed previousCosigner, address indexed newCosigner);

	// ---------------------------------------------------------------------
	// State
	// ---------------------------------------------------------------------
	address public owner;
	address public cosigner;

	/// @dev nonces[signer] => next expected nonce
	mapping(address => uint256) public nonces;

	// ---------------------------------------------------------------------
	// EIP-712 typehashes
	// ---------------------------------------------------------------------
	bytes32 private constant UPDATE_OWNER_TYPEHASH =
		keccak256("UpdateOwner(address newOwner,uint256 nonce)");
	bytes32 private constant UPDATE_COSIGNER_TYPEHASH =
		keccak256("UpdateCosigner(address newCosigner,uint256 nonce)");

	// ---------------------------------------------------------------------
	// Modifiers
	// ---------------------------------------------------------------------
	modifier onlyOwner() {
		if (msg.sender != owner) revert NotOwner();
		_;
	}

	// ---------------------------------------------------------------------
	// Constructor
	// ---------------------------------------------------------------------
	constructor(address owner_, address cosigner_)
		ERC20("QBitFlow Test USD", "QBFT")
		EIP712("QBFT", "1")
	{
		if (owner_ == address(0) || cosigner_ == address(0) || owner_ == cosigner_) {
			revert InvalidAddress();
		}
		owner = owner_;
		cosigner = cosigner_;
		emit OwnerUpdated(address(0), owner_);
		emit CosignerUpdated(address(0), cosigner_);
	}

	// ---------------------------------------------------------------------
	// Metadata
	// ---------------------------------------------------------------------
	function decimals() public pure override returns (uint8) {
		return 6;
	}

	// ---------------------------------------------------------------------
	// Faucet
	// ---------------------------------------------------------------------
	/// @notice Mint tokens to any address. Testnet faucet primitive.
	function mint(address to, uint256 amount) external onlyOwner {
		if (to == address(0)) revert InvalidAddress();
		_mint(to, amount);
	}

	// ---------------------------------------------------------------------
	// Governance
	// ---------------------------------------------------------------------
	function updateOwner(
		address newOwner,
		uint256 nonce,
		bytes calldata cosignerSig
	) external onlyOwner {
		if (
			newOwner == address(0) ||
			newOwner == owner ||
			newOwner == cosigner ||
			newOwner == address(this)
		) revert InvalidAddress();

		_consumeNonce(cosigner, nonce);
		_validateSignature(
			keccak256(abi.encode(UPDATE_OWNER_TYPEHASH, newOwner, nonce)),
			cosigner,
			cosignerSig
		);

		address prev = owner;
		owner = newOwner;
		emit OwnerUpdated(prev, newOwner);
	}

	function updateCosigner(
		address newCosigner,
		uint256 nonce,
		bytes calldata cosignerSig
	) external onlyOwner {
		if (
			newCosigner == address(0) ||
			newCosigner == cosigner ||
			newCosigner == owner ||
			newCosigner == address(this)
		) revert InvalidAddress();

		// Current cosigner signs off on their own replacement.
		_consumeNonce(cosigner, nonce);
		_validateSignature(
			keccak256(abi.encode(UPDATE_COSIGNER_TYPEHASH, newCosigner, nonce)),
			cosigner,
			cosignerSig
		);

		address prev = cosigner;
		cosigner = newCosigner;
		emit CosignerUpdated(prev, newCosigner);
	}

	// ---------------------------------------------------------------------
	// Internal
	// ---------------------------------------------------------------------
	function _consumeNonce(address signer, uint256 nonce) internal {
		if (nonces[signer] != nonce) revert InvalidNonce();
		unchecked {
			nonces[signer] = nonce + 1;
		}
	}

	function _validateSignature(
		bytes32 structHash,
		address expectedSigner,
		bytes calldata sig
	) internal view {
		bytes32 digest = _hashTypedDataV4(structHash);
		address recovered = ECDSA.recover(digest, sig);
		if (recovered != expectedSigner) revert InvalidSignature();
	}
}