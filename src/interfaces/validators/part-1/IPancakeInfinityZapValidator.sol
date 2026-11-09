// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPancakeInfinityZapValidator {
  error ZapInPancakeInfinityInsufficientLiquidity();
  error ZapInPancakeInfinityInvalidPositionInfo();
  error PancakeInfinityInvalidPositionOwner();
  error RemovePancakeInfinityInvalidLiquidity();

  /**
   * @notice The input for validating Pancake Infinity before execution
   * @param posManager The address of the position manager
   * @param tokenId The token ID of the position
   */
  struct PancakeInfinityBeforeExecutionInput {
    address posManager;
    uint256 tokenId;
  }

  /**
   * @notice The input for validating Pancake Infinity after zap-in execution
   * @param expectedPositionInfo The expected position info
   * @param minLiquidity The minimum liquidity to add
   * @param recipient The recipient of the NFT position
   */
  struct ZapInPancakeInfinityAfterExecutionInput {
    uint256 expectedPositionInfo;
    uint256 minLiquidity;
    address recipient;
  }

  /**
   * @notice The input for validating Pancake Infinity after remove execution
   * @param liquidityRemoved The liquidity to remove
   * @param recipient The recipient of the refunded NFT position
   */
  struct RemovePancakeInfinityAfterExecutionInput {
    uint256 liquidityRemoved;
    address recipient;
  }
}
