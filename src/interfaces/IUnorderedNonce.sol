// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IUnorderedNonce
/// @notice Interface of {UnorderedNonce}
interface IUnorderedNonce {
  /// @notice Thrown when a nonce that is already used is used again
  error NonceAlreadyUsed();

  /**
   * @notice Returns the bitmap of the used nonces of an owner in one word
   * @param owner The owner of the nonces
   * @param word The word, equal to a nonce shifted right by 8 bits
   * @return bitmap The bitmap whose bit at the bottom 8 bits of a nonce is set when that nonce is
   * used
   */
  function nonces(address owner, uint256 word) external view returns (uint256 bitmap);

  /**
   * @notice Marks a nonce of the caller as used, so that no signature with it can be used
   * @param nonce The nonce
   */
  function revokeNonce(uint256 nonce) external;
}
