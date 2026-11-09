// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IZapAddLiquidityPreviewHelper
/// @notice Interface of the helper a settler queries for the amounts to add as liquidity, implemented
/// for the liquidity sources whose position managers do not compute these amounts
interface IZapAddLiquidityPreviewHelper {
  /**
   * @notice Previews an addition of liquidity without a swap at the current pool state
   * @param fixedParams ABI-encoded fixed parameters specific to the liquidity source
   * @param variableParams ABI-encoded amounts to add
   * @return result ABI-encoded preview specific to the liquidity source
   */
  function previewAddLiquidity(bytes calldata fixedParams, bytes calldata variableParams)
    external
    view
    returns (bytes memory result);
}
