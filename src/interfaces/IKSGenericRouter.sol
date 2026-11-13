// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IKSGenericRouter
/// @notice Interface every router implements to be called by the allowance hub
interface IKSGenericRouter {
  /**
   * @notice Runs one router action for the account the allowance hub's `msgSender` returns
   * @param data Router-specific payload
   * @return Router-specific return data, which the allowance hub returns to its caller
   */
  function ksExecute(bytes calldata data) external payable returns (bytes memory);
}
