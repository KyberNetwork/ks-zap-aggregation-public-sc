// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidityAmounts} from '../vendors/uniswap-v4/LiquidityAmounts.sol';
import {SqrtPriceMath} from '../vendors/uniswap-v4/SqrtPriceMath.sol';

/// @title AddLiquidityAmounts
/// @notice Computes the liquidity that amounts add to a price range and the amounts it requires
library AddLiquidityAmounts {
  /**
   * @dev Computes the liquidity that the amounts add to the price range at the price, and the
   * amounts of token0 and token1, rounded up, that the liquidity requires
   * @param sqrtPriceX96 The current price
   * @param sqrtPriceLowerX96 The lower price of the range
   * @param sqrtPriceUpperX96 The upper price of the range
   * @param amount0 The amount of token0 to add
   * @param amount1 The amount of token1 to add
   * @return liquidity The liquidity added
   * @return addedAmount0 The amount of token0 the liquidity requires
   * @return addedAmount1 The amount of token1 the liquidity requires
   */
  function preview(
    uint160 sqrtPriceX96,
    uint160 sqrtPriceLowerX96,
    uint160 sqrtPriceUpperX96,
    uint256 amount0,
    uint256 amount1
  ) internal pure returns (uint128 liquidity, uint256 addedAmount0, uint256 addedAmount1) {
    liquidity = uint128(
      LiquidityAmounts.getLiquidityForAmounts(
        sqrtPriceX96, sqrtPriceLowerX96, sqrtPriceUpperX96, amount0, amount1
      )
    );

    if (sqrtPriceX96 <= sqrtPriceLowerX96) {
      addedAmount0 =
        SqrtPriceMath.getAmount0Delta(sqrtPriceLowerX96, sqrtPriceUpperX96, liquidity, true);
    } else if (sqrtPriceX96 < sqrtPriceUpperX96) {
      addedAmount0 = SqrtPriceMath.getAmount0Delta(sqrtPriceX96, sqrtPriceUpperX96, liquidity, true);
      addedAmount1 = SqrtPriceMath.getAmount1Delta(sqrtPriceLowerX96, sqrtPriceX96, liquidity, true);
    } else {
      addedAmount1 =
        SqrtPriceMath.getAmount1Delta(sqrtPriceLowerX96, sqrtPriceUpperX96, liquidity, true);
    }
  }
}
