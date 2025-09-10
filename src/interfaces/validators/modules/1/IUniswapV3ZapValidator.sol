// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PackedU8} from '../../../../types/PackedU8.sol';

interface IUniswapV3ZapValidator {
  error ZapIn__UniswapV3Fork__InvalidTickRange();
  error ZapIn__UniswapV3Fork__InsufficientLiquidity();
  error UniswapV3Fork__InvalidPositionOwner();
  error Remove__UniswapV3Fork__InvalidLiquidity();

  struct UniswapV3Fork_BeforeExecutionInput {
    address posManager;
    uint256 tokenId;
    PackedU8 positionDataOffsets;
  }

  struct ZapIn__UniswapV3Fork_AfterExecutionInput {
    int256 tickLower;
    int256 tickUpper;
    uint256 minLiquidity;
    address recipient;
  }

  struct Remove__UniswapV3Fork_AfterExecutionInput {
    uint256 liquidityRemoved;
    address recipient;
  }
}
