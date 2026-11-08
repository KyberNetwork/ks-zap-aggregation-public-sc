// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IZapSettler
/// @notice Interface every settler implements to be called by the allowance hub in owner calls
interface IZapSettler {
  /// @notice Emitted when liquidity is added
  /// @param zapInLogData ABI-encoded log data specific to the settler
  event ZapIn(bytes zapInLogData);

  /**
   * @notice Adds liquidity with the token balances this contract holds
   * @param data ABI-encoded parameters specific to the settler
   * @return result ABI-encoded result specific to the settler
   */
  function ksExecute(bytes calldata data) external payable returns (bytes memory result);
}
