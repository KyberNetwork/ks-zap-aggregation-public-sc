// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapValidatorV3} from '../interfaces/IKSZapValidatorV3.sol';

abstract contract KSZapValidatorV3Base is IKSZapValidatorV3 {
  function beforeExecution(bytes32 zapType, bytes calldata beforeExecutionInput)
    external
    view
    returns (bytes memory)
  {
    return get_beforeExecution_handler(zapType)(beforeExecutionInput);
  }

  function afterExecution(
    bytes32 zapType,
    bytes calldata beforeExecutionInput,
    bytes calldata beforeExecutionOutput,
    bytes calldata afterExecutionInput
  ) external view {
    return get_afterExecution_handler(zapType)(
      beforeExecutionInput, beforeExecutionOutput, afterExecutionInput
    );
  }

  function get_beforeExecution_handler(bytes32 zapType)
    internal
    pure
    virtual
    returns (function(bytes calldata) internal view returns (bytes memory));

  function get_afterExecution_handler(bytes32 zapType)
    internal
    pure
    virtual
    returns (function(bytes calldata, bytes calldata, bytes calldata) internal view);
}
