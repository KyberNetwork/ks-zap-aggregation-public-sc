// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Interface for the KS Zap Validator V3
interface IKSZapValidatorV3 {
  /// @notice Thrown when the zap action is invalid
  error InvalidZapAction(bytes32 zapAction);

  /// @notice Returns the state before execution
  function beforeExecution(bytes32 zapAction, bytes calldata _beforeExecutionInput)
    external
    returns (bytes memory beforeExecutionOutput);

  /// @notice Validates the current state after execution against the before execution state
  function afterExecution(
    bytes32 zapAction,
    bytes calldata _beforeExecutionInput,
    bytes calldata beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) external;
}
