// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IZapPoolSwapHelper
/// @notice Interface of the helper that the executor of a solver call delegatecalls for the pool
/// swap of a zap in
interface IZapPoolSwapHelper {
  /**
   * @notice Swaps the given amounts of the pool tokens on the pool towards the ratio of the
   * position
   * @dev The amounts in `additionalData` are used instead of the balances.
   * @param ownerData ABI-encoded owner parameters of the zap in, as the adapter received them
   * @param solverData ABI-encoded solver parameters of the zap in, as the adapter received them
   * @param additionalData ABI-encoded data specific to the liquidity source that the adapter adds:
   * the amounts to swap and whether the extra data of the solver is used
   * @return result ABI-encoded result specific to the liquidity source
   */
  function poolSwap(
    bytes calldata ownerData,
    bytes calldata solverData,
    bytes calldata additionalData
  ) external payable returns (bytes memory result);
}
