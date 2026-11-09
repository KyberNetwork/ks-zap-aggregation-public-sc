// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PackedBits} from '../../../types/PackedBits.sol';

interface IUniswapV3ForkZapValidator {
  error ZapInUniswapV3ForkInvalidPositionData();
  error ZapInUniswapV3ForkInsufficientLiquidity();
  error UniswapV3ForkInvalidPositionOwner();
  error RemoveUniswapV3ForkInvalidLiquidity();

  /**
   * @notice The input for validating Uniswap V3 Fork before execution
   * @param posManager The address of the position manager
   * @param tokenId The token ID of the position
   * @param liquidityOffset The liquidity offset
   */
  struct UniswapV3ForkBeforeExecutionInput {
    address posManager;
    uint256 tokenId;
    uint256 liquidityOffset;
  }

  /**
   * @notice The input for validating Uniswap V3 Fork after zap-in execution
   * @param expectedPositionData The expected position data
   * @param needCheckFields The need check fields
   * @param minLiquidity The minimum liquidity to add
   * @param recipient The recipient of the NFT position
   */
  struct ZapInUniswapV3ForkAfterExecutionInput {
    bytes expectedPositionData;
    PackedBits needCheckFields;
    uint256 minLiquidity;
    address recipient;
  }

  /**
   * @notice The input for validating Uniswap V3 Fork after remove execution
   * @param liquidityRemoved The liquidity to remove
   * @param recipient The recipient of the refunded NFT position
   */
  struct RemoveUniswapV3ForkAfterExecutionInput {
    uint256 liquidityRemoved;
    address recipient;
  }
}
