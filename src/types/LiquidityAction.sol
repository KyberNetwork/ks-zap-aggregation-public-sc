// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Action of a liquidity source adapter, the first element of its owner data
enum LiquidityAction {
  /// Adds the balances held to a position, with the zap-in parameters of the source as the action
  /// parameters
  ADD_LIQUIDITY,
  /// Removes liquidity from a position and collects it, with the remove parameters of the source
  /// as the action parameters
  REMOVE_LIQUIDITY
}
