// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IKSZapValidatorV3 {
  function beforeExecution(bytes32 zapType, bytes calldata zapInfo)
    external
    view
    returns (bytes memory);

  function afterExecution(
    bytes32 zapType,
    bytes calldata zapInfo,
    bytes calldata beforeExecutionData
  ) external view;
}
