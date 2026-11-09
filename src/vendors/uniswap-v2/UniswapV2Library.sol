// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library UniswapV2Library {
  // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
  function getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut,
    uint256 swapFee,
    uint256 feeDenominator
  ) internal pure returns (uint256 amountOut) {
    unchecked {
      uint256 amountInWithFee = amountIn * (feeDenominator - swapFee);
      uint256 numerator = amountInWithFee * reserveOut;
      uint256 denominator = reserveIn * feeDenominator + amountInWithFee;
      amountOut = numerator / denominator;
    }
  }
}
