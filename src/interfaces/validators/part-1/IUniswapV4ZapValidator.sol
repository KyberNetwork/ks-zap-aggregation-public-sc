// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV4ZapValidator {
  error ZapInUniswapV4InsufficientLiquidity();
  error ZapInUniswapV4InvalidPositionInfo();
  error UniswapV4InvalidPositionOwner();
  error RemoveUniswapV4InvalidLiquidity();

  /**
   * @notice The input for validating Uniswap V4 before execution
   * @param posManager The address of the position manager
   * @param tokenId The token ID of the position
   */
  struct UniswapV4BeforeExecutionInput {
    address posManager;
    uint256 tokenId;
  }

  /**
   * @notice The input for validating Uniswap V4 after zap-in execution
   * @param expectedPositionInfo The expected position info
   * @param minLiquidity The minimum liquidity to add
   * @param recipient The recipient of the NFT position
   */
  struct ZapInUniswapV4AfterExecutionInput {
    uint256 expectedPositionInfo;
    uint256 minLiquidity;
    address recipient;
  }

  /**
   * @notice The input for validating Uniswap V4 after remove execution
   * @param liquidityRemoved The liquidity to remove
   * @param recipient The recipient of the refunded NFT position
   */
  struct RemoveUniswapV4AfterExecutionInput {
    uint256 liquidityRemoved;
    address recipient;
  }
}
