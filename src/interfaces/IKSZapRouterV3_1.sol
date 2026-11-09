// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IKSZapRouterV3_1
/// @notice Interface of {KSZapRouterV3_1}
interface IKSZapRouterV3_1 {
  /// @notice Thrown when the deadline is passed
  error DeadlinePassed(uint256 deadline, uint256 blockTimestamp);

  /// @notice Thrown when failed to call the executor
  error CallExecutorFailed();

  /// @notice Emitted when a zap is executed
  event Zap(address executor);

  /// @notice Emitted when the client data is set
  event ClientData(bytes clientData);

  /**
   * @notice Called by the allowance hub to execute a zap
   * @param data The ABI-encoded `ZapParamsV3_1` and the signer's signature of it
   * @return result The result of the executor call
   */
  function ksExecute(bytes calldata data) external payable returns (bytes memory result);

  /**
   * @notice Returns the address that called the zap function
   * @return The caller of the ongoing zap
   */
  function msgSender() external view returns (address);
}
