// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PackedBits} from '../../../../types/PackedBits.sol';

interface IUniswapV3ForkZapValidator {
  error ZapInUniswapV3ForkInvalidPositionData();
  error ZapInUniswapV3ForkInsufficientLiquidity();
  error UniswapV3ForkInvalidPositionOwner();
  error RemoveUniswapV3ForkInvalidLiquidity();

  struct UniswapV3ForkBeforeExecutionInput {
    address posManager;
    uint256 tokenId;
    uint256 liquidityOffset;
  }

  struct ZapInUniswapV3ForkAfterExecutionInput {
    bytes expectedPositionData;
    PackedBits needCheckFields;
    uint256 minLiquidity;
    address recipient;
  }

  struct RemoveUniswapV3ForkAfterExecutionInput {
    uint256 liquidityRemoved;
    address recipient;
  }
}
