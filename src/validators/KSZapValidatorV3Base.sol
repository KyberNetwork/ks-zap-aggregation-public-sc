// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapValidatorV3} from '../interfaces/IKSZapValidatorV3.sol';

abstract contract KSZapValidatorV3Base is IKSZapValidatorV3 {
  function beforeExecution(bytes32 zapType, bytes calldata _beforeExecutionInput)
    external
    view
    returns (bytes memory)
  {
    return getBeforeExecutionHandler(zapType)(_beforeExecutionInput);
  }

  function afterExecution(
    bytes32 zapType,
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) external view {
    return getAfterExecutionHandler(zapType)(
      _beforeExecutionInput, _beforeExecutionOutput, _afterExecutionInput
    );
  }

  function getBeforeExecutionHandler(bytes32 zapType)
    internal
    pure
    virtual
    returns (function(bytes calldata) internal view returns (bytes memory));

  function getAfterExecutionHandler(bytes32 zapType)
    internal
    pure
    virtual
    returns (function(bytes calldata, bytes calldata, bytes calldata) internal view);
}
