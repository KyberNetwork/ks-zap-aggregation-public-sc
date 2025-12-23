// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Interface for the KS Zap Validator V3
interface IKSZapValidatorV3 {
  /// @notice Thrown when the zap action is invalid
  error InvalidZapAction(bytes32 zapAction);

  /**
   * @notice Returns the state before execution
   * @param zapAction The type of zap action
   * @param _beforeExecutionInput The before execution input
   * @return _beforeExecutionOutput The output representing the state before execution
   */
  function beforeExecution(bytes32 zapAction, bytes calldata _beforeExecutionInput)
    external
    returns (bytes memory _beforeExecutionOutput);

  /**
   * @notice Validates the current state after execution against the before execution state
   * @param zapAction The type of zap action
   * @param _beforeExecutionInput The before execution input
   * @param _beforeExecutionOutput The output from calling the before execution function
   * @param _afterExecutionInput The after execution input
   */
  function afterExecution(
    bytes32 zapAction,
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) external;
}
