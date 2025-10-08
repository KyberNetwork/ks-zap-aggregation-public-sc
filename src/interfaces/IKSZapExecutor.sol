// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Interface for the KS Zap Executor
interface IKSZapExecutor {
  /// @notice Entry point for the zap executor
  function executeZap(bytes calldata data) external payable returns (bytes memory result);
}
