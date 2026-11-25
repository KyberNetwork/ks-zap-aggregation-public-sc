// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IZapHelper
/// @notice Interface of the zap helpers
interface IZapHelper {
  /**
   * @notice Previews the pool swap and the addition of liquidity of a zap in
   * @param ownerData ABI-encoded owner parameters of the zap in, as the adapter receives them
   * @param solverData ABI-encoded solver parameters of the zap in, as the adapter receives them
   * @param additionalData ABI-encoded data specific to the liquidity source: the amounts to swap
   * and add
   * @return ABI-encoded preview specific to the liquidity source
   */
  function previewZapIn(
    bytes calldata ownerData,
    bytes calldata solverData,
    bytes calldata additionalData
  ) external view returns (bytes memory);

  /**
   * @notice Previews the removal of liquidity
   * @param ownerData ABI-encoded owner parameters of the removal, as the adapter receives them
   * @param solverData ABI-encoded solver parameters of the removal, as the adapter receives them
   * @param additionalData ABI-encoded data specific to the liquidity source
   * @return ABI-encoded preview specific to the liquidity source
   */
  function previewRemove(
    bytes calldata ownerData,
    bytes calldata solverData,
    bytes calldata additionalData
  ) external view returns (bytes memory);

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
