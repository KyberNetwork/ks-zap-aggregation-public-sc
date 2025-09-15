// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PackedU8} from '../../../../types/PackedU8.sol';

interface IUniswapV3ForkZapValidator {
  error ZapInUniswapV3ForkInvalidTickRange();
  error ZapInUniswapV3ForkInsufficientLiquidity();
  error UniswapV3ForkInvalidPositionOwner();
  error RemoveUniswapV3ForkInvalidLiquidity();

  struct UniswapV3ForkBeforeExecutionInput {
    address posManager;
    uint256 tokenId;
    PackedU8 positionDataOffsets;
  }

  struct ZapInUniswapV3ForkAfterExecutionInput {
    int256 tickLower;
    int256 tickUpper;
    uint256 minLiquidity;
    address recipient;
  }

  struct RemoveUniswapV3ForkAfterExecutionInput {
    uint256 liquidityRemoved;
    address recipient;
  }
}
