// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUnorderedNonce} from '../interfaces/IUnorderedNonce.sol';

/// @title UnorderedNonce
/// @notice Records the used signature nonces of each owner in bitmaps, so that the nonces can be
/// used in any order
abstract contract UnorderedNonce is IUnorderedNonce {
  /// @inheritdoc IUnorderedNonce
  mapping(address owner => mapping(uint256 word => uint256 bitmap)) public nonces;

  /// @inheritdoc IUnorderedNonce
  function revokeNonce(uint256 nonce) external {
    _useUnorderedNonce(msg.sender, nonce);
  }

  /**
   * @dev Marks a nonce of an owner as used, and reverts when it is already used. The top 248 bits
   * of the nonce select the word and the bottom 8 bits select the bit in the word.
   * @param owner The owner of the nonce
   * @param nonce The nonce
   */
  function _useUnorderedNonce(address owner, uint256 nonce) internal {
    uint256 word = nonce >> 8;
    uint256 bit = 1 << uint8(nonce);
    uint256 flipped = nonces[owner][word] ^= bit;
    require(flipped & bit != 0, NonceAlreadyUsed());
  }
}
