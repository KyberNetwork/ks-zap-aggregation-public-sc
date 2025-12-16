// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ValidateParams} from './ValidateParams.sol';

/**
 * @notice Parameters for the zap action
 * @param validateParams The array of parameters for validation
 * @param executor The address of the executor
 * @param executorData The data to call the executor with
 * @param deadline The deadline for the zap action
 * @param clientData The client data
 */
struct ZapParams {
  ValidateParams[] validateParams;
  address executor;
  bytes executorData;
  uint256 deadline;
  bytes clientData;
}
