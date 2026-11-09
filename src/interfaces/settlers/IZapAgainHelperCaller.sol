// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IZapAgainHelperCaller
/// @notice Interface of {ZapAgainHelperCaller}
interface IZapAgainHelperCaller {
  /// @notice Thrown when a callback is received outside the pool swap of a zap again
  /// @param caller The caller of the callback
  error ZapAgainCallbackNotExpected(address caller);
}
