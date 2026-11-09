// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice Parameters for the zap action of {KSZapRouterV3_1}
 * @param executor The address of the executor
 * @param executorData The data to call the executor with
 * @param deadline The deadline for the zap action
 * @param clientData The client data
 */
struct ZapParamsV3_1 {
  address executor;
  bytes executorData;
  uint256 deadline;
  bytes clientData;
}
