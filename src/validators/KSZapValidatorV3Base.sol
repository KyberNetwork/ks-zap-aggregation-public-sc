// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapValidatorV3} from '../interfaces/IKSZapValidatorV3.sol';

abstract contract KSZapValidatorV3Base is IKSZapValidatorV3 {
  /// @inheritdoc IKSZapValidatorV3
  function beforeExecution(bytes32 zapAction, bytes calldata _beforeExecutionInput)
    external
    returns (bytes memory)
  {
    return getBeforeExecutionHandler(zapAction)(_beforeExecutionInput);
  }

  /// @inheritdoc IKSZapValidatorV3
  function afterExecution(
    bytes32 zapAction,
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) external {
    return getAfterExecutionHandler(
      zapAction
    )(_beforeExecutionInput, _beforeExecutionOutput, _afterExecutionInput);
  }

  function getBeforeExecutionHandler(bytes32 zapAction)
    internal
    pure
    virtual
    returns (function(bytes calldata) internal returns (bytes memory));

  function getAfterExecutionHandler(bytes32 zapAction)
    internal
    pure
    virtual
    returns (function(bytes calldata, bytes calldata, bytes calldata) internal);

  function _beforeExecutionDummy(bytes calldata _beforeExecutionInput)
    internal
    view
    returns (bytes memory)
  {}

  function _afterExecutionDummy(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {}
}
