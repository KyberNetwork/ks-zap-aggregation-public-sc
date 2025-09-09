// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapValidatorV3} from '../interfaces/IKSZapValidatorV3.sol';

/**
 * @notice Params structure for validation
 * @param validator The address of the validator
 * @param zapType The type of zap action
 * @param zapInfo The info of zap action
 */
struct ValidateParams {
  address validator;
  bytes32 zapType;
  bytes zapInfo;
}

using ValidateParamsLibrary for ValidateParams global;

/// @notice Contains functions for processing validate params
library ValidateParamsLibrary {
  function beforeExecution(ValidateParams calldata self) internal view returns (bytes memory) {
    return IKSZapValidatorV3(self.validator).beforeExecution(self.zapType, self.zapInfo);
  }

  function afterExecution(ValidateParams calldata self, bytes memory beforeExecutionData)
    internal
    view
  {
    IKSZapValidatorV3(self.validator).afterExecution(
      self.zapType, self.zapInfo, beforeExecutionData
    );
  }
}
