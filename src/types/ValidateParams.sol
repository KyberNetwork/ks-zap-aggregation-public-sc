// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapValidatorV3} from '../interfaces/IKSZapValidatorV3.sol';

/**
 * @notice Params structure for validation
 * @param validator The address of the validator
 * @param zapAction The type of zap action
 * @param beforeExecutionInput The input for before execution
 * @param afterExecutionInput The input for after execution
 */
struct ValidateParams {
  address validator;
  bytes32 zapAction;
  bytes beforeExecutionInput;
  bytes afterExecutionInput;
}

using ValidateParamsLibrary for ValidateParams global;

/// @notice Contains functions for processing validate params
library ValidateParamsLibrary {
  /// @notice Returns the state before execution
  function beforeExecution(ValidateParams calldata self) internal returns (bytes memory) {
    return
      IKSZapValidatorV3(self.validator).beforeExecution(self.zapAction, self.beforeExecutionInput);
  }

  /// @notice Validates the current state after execution against the before execution state
  function afterExecution(ValidateParams calldata self, bytes memory beforeExecutionOutput)
    internal
  {
    IKSZapValidatorV3(self.validator)
      .afterExecution(
        self.zapAction, self.beforeExecutionInput, beforeExecutionOutput, self.afterExecutionInput
      );
  }
}
