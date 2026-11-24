// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UnorderedNonce} from './UnorderedNonce.sol';

import {IERC721Permit_v4} from 'ks-common-sc/src/interfaces/IERC721Permit_v4.sol';
import {ERC721} from 'openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import {EIP712} from 'openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol';
import {
  SignatureChecker
} from 'openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol';

/// @title ERC721Permit
/// @notice ERC721 token whose approvals can be given by EIP-712 signatures of the owner, with
/// unordered nonces. Signatures of contract owners are verified with ERC-1271.
abstract contract ERC721Permit is IERC721Permit_v4, UnorderedNonce, ERC721, EIP712 {
  /// @notice Thrown when a signature is not valid for the owner
  error InvalidSignature();

  /// @notice keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)")
  bytes32 public constant PERMIT_TYPEHASH =
    0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;

  /// @notice keccak256("PermitForAll(address operator,bool approved,uint256 nonce,uint256
  /// deadline)")
  bytes32 public constant PERMIT_FOR_ALL_TYPEHASH =
    0x6673cb397ee2a50b6b8401653d3638b4ac8b3db9c28aa6870ffceb7574ec2f76;

  /**
   * @param name The name of the token and of the EIP-712 domain
   * @param symbol The symbol of the token
   */
  constructor(string memory name, string memory symbol) ERC721(name, symbol) EIP712(name, '1') {}

  /// @dev Requires that the deadline of a signature has not passed
  modifier checkSignatureDeadline(uint256 deadline) {
    require(block.timestamp <= deadline, SignatureDeadlineExpired());
    _;
  }

  /// @inheritdoc IERC721Permit_v4
  function permit(
    address spender,
    uint256 tokenId,
    uint256 deadline,
    uint256 nonce,
    bytes calldata signature
  ) external payable checkSignatureDeadline(deadline) {
    address owner = ownerOf(tokenId);

    bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, spender, tokenId, nonce, deadline));
    _verifySignature(owner, structHash, signature);

    _useUnorderedNonce(owner, nonce);
    _approve(spender, tokenId, address(0));
  }

  /// @inheritdoc IERC721Permit_v4
  function permitForAll(
    address owner,
    address operator,
    bool approved,
    uint256 deadline,
    uint256 nonce,
    bytes calldata signature
  ) external payable checkSignatureDeadline(deadline) {
    bytes32 structHash = keccak256(
      abi.encode(PERMIT_FOR_ALL_TYPEHASH, operator, approved, nonce, deadline)
    );
    _verifySignature(owner, structHash, signature);

    _useUnorderedNonce(owner, nonce);
    _setApprovalForAll(owner, operator, approved);
  }

  /**
   * @dev Requires a valid EIP-712 signature of the owner over the struct hash
   * @param owner The owner whose signature is verified
   * @param structHash The hash of the signed struct
   * @param signature The signature, verified with ECDSA for an account without code and with
   * ERC-1271 otherwise
   */
  function _verifySignature(address owner, bytes32 structHash, bytes calldata signature)
    internal
    view
  {
    bytes32 digest = _hashTypedDataV4(structHash);
    require(
      SignatureChecker.isValidSignatureNowCalldata(owner, digest, signature), InvalidSignature()
    );
  }
}
