// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IKSZapValidatorV3 {
  error InvalidZapType(bytes32 zapType);

  function beforeExecution(bytes32 zapType, bytes calldata beforeExecutionInput)
    external
    view
    returns (bytes memory beforeExecutionOutput);

  function afterExecution(
    bytes32 zapType,
    bytes calldata beforeExecutionInput,
    bytes calldata beforeExecutionOutput,
    bytes calldata afterExecutionInput
  ) external view;
}
