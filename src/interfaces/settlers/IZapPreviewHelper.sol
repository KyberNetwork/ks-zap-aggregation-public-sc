// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IZapPreviewHelper
/// @notice Interface of the helper a settler queries for the pool swap of a zap again
interface IZapPreviewHelper {
  /**
   * @notice Previews a zap into a position at the current pool state
   * @param fixedParams ABI-encoded fixed parameters specific to the liquidity source
   * @param variableParams ABI-encoded amounts to zap in
   * @return result ABI-encoded preview specific to the liquidity source
   */
  function previewZapIn(bytes calldata fixedParams, bytes calldata variableParams)
    external
    view
    returns (bytes memory result);
}
