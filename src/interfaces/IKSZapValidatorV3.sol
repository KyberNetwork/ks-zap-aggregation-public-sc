// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Interface for the KS Zap Validator V3
interface IKSZapValidatorV3 {
  /// @notice Thrown when the zap type is invalid
  error InvalidZapType(bytes32 zapType);

  /// @notice Returns the state before execution
  function beforeExecution(bytes32 zapType, bytes calldata _beforeExecutionInput)
    external
    view
    returns (bytes memory beforeExecutionOutput);

  /// @notice Validates the current state after execution against the before execution state
  function afterExecution(
    bytes32 zapType,
    bytes calldata _beforeExecutionInput,
    bytes calldata beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) external view;
}
