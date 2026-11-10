// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV2Pair} from '../../vendors/uniswap-v2/IUniswapV2Pair.sol';

import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

/// @title UniswapV2MintLibrary
/// @notice Computes the liquidity and the token amounts of a Uniswap V2 mint
library UniswapV2MintLibrary {
  using Math for uint256;

  /**
   * @dev Computes the liquidity minted by the given amounts and the amount of each token it
   * consumes, using the reserves of the pair and its total supply including the pending protocol
   * fee
   * @param pool The pair
   * @param protocolFee The protocol fee
   * @param swapFee The swap fee
   * @param amount0 The amount of token0 available
   * @param amount1 The amount of token1 available
   * @return liquidity The liquidity minted
   * @return addedAmount0 The amount of token0 consumed
   * @return addedAmount1 The amount of token1 consumed
   */
  function previewMint(
    IUniswapV2Pair pool,
    uint24 protocolFee,
    uint24 swapFee,
    uint256 amount0,
    uint256 amount1
  ) internal view returns (uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1) {
    (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
    uint256 totalSupply = computeActualTotalSupply(pool, protocolFee, swapFee, reserve0, reserve1);

    liquidity = Math.min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1);

    addedAmount0 = (liquidity * reserve0).ceilDiv(totalSupply);
    addedAmount1 = (liquidity * reserve1).ceilDiv(totalSupply);
  }

  /**
   * @dev Returns the total supply of a pair including the liquidity pending to be minted as the
   * protocol fee. The pending fee is omitted when the pair does not expose `kLast`.
   * @param pool The pair
   * @param protocolFee The protocol fee
   * @param swapFee The swap fee
   * @param reserve0 The reserve of token0
   * @param reserve1 The reserve of token1
   * @return totalSupply The total supply including the pending protocol fee
   */
  function computeActualTotalSupply(
    IUniswapV2Pair pool,
    uint24 protocolFee,
    uint24 swapFee,
    uint256 reserve0,
    uint256 reserve1
  ) internal view returns (uint256 totalSupply) {
    totalSupply = pool.totalSupply();

    try pool.kLast() returns (uint256 kLast) {
      if (protocolFee != 0 && kLast != 0) {
        uint256 rootKLast = kLast.sqrt();
        uint256 rootK = (reserve0 * reserve1).sqrt();

        if (rootK > rootKLast) {
          uint256 numerator = totalSupply * (rootK - rootKLast) * protocolFee;
          uint256 denominator = rootK * (swapFee - protocolFee) + rootKLast * protocolFee;
          totalSupply += numerator / denominator;
        }
      }
    } catch {
      return totalSupply;
    }
  }
}
