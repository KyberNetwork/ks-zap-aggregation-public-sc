// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ValidateParams} from '../types/ValidateParams.sol';

/// @notice Interface for the KS Zap Router V3
interface IKSZapRouterV3 {
  /// @notice Thrown when the deadline is passed
  error DeadlinePassed(uint256 deadline, uint256 blockTimestamp);

  /// @notice Thrown when failed to call the executor
  error CallExecutorFailed();

  event Zap(ValidateParams[] validateParams, address executor);

  /// @notice Emitted when the client data is set
  event ClientData(bytes clientData);

  /**
   * @notice Called by the allowance hub to execute zap action.
   * @param data The encoded data of `ZapParams` struct.
   */
  function ksExecute(bytes calldata data) external payable returns (bytes memory result);

  /// @notice Returns the address that called the zap function
  function msgSender() external view returns (address);
}
