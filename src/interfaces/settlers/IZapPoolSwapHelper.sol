// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IZapPoolSwapHelper
/// @notice Interface of the helper a settler delegatecalls for the pool swap of a zap again
interface IZapPoolSwapHelper {
  /// @param poolSwapLogData ABI-encoded result of the pool swap
  event PoolSwap(bytes poolSwapLogData);

  /**
   * @notice Swaps the caller's balances of the pool tokens on the pool towards the ratio of the
   * position
   * @param fixedParams ABI-encoded fixed parameters specific to the liquidity source
   * @param variableParams ABI-encoded variable parameters specific to the liquidity source
   * @return result ABI-encoded result specific to the liquidity source
   */
  function poolSwap(bytes calldata fixedParams, bytes calldata variableParams)
    external
    payable
    returns (bytes memory result);
}
