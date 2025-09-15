// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV4ZapValidator {
  error ZapInUniswapV4InsufficientLiquidity();
  error ZapInUniswapV4InvalidTickRange();
  error UniswapV4InvalidPositionOwner();
  error RemoveUniswapV4InvalidLiquidity();

  struct UniswapV4BeforeExecutionInput {
    address posManager;
    uint256 tokenId;
  }

  struct ZapInUniswapV4AfterExecutionInput {
    int24 tickLower;
    int24 tickUpper;
    uint256 minLiquidity;
    address recipient;
  }

  struct RemoveUniswapV4AfterExecutionInput {
    uint256 liquidityRemoved;
    address recipient;
  }
}
