// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Action of a liquidity source adapter, encoded as the first byte of its owner data
enum LiquidityAction {
  /// Adds the token balances of the proxy to a position; the action parameters are the zap-in
  /// owner parameters of the source
  ADD_LIQUIDITY,
  /// Removes liquidity from a position and collects the amounts; the action parameters are the
  /// remove owner parameters of the source
  REMOVE_LIQUIDITY
}
