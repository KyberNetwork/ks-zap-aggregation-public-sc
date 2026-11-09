// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IZapPairPreviewHelper
/// @notice Interface of the helper a settler queries for the amounts minted into a pair
interface IZapPairPreviewHelper {
  /**
   * @notice The result of previewing a mint into a pair
   * @param liquidity The liquidity minted
   * @param addedAmount0 The amount of token0 added
   * @param addedAmount1 The amount of token1 added
   */
  struct PreviewMintResult {
    uint256 liquidity;
    uint256 addedAmount0;
    uint256 addedAmount1;
  }

  /**
   * @notice Previews a mint into a pair at the current pool state without a swap
   * @param fixedParams ABI-encoded fixed parameters of the zap in, specific to the liquidity source
   * @param variableParams ABI-encoded amounts to mint with
   * @return result ABI-encoded {PreviewMintResult}
   */
  function previewMint(bytes calldata fixedParams, bytes calldata variableParams)
    external
    view
    returns (bytes memory result);
}
