// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IZapAlgebraSettler} from '../../interfaces/settlers/algebra/IZapAlgebraSettler.sol';
import {ZapUniswapV3Settler} from '../uniswap-v3/ZapUniswapV3Settler.sol';

import {IAlgebraV1_9NFT} from '../../vendors/algebra-v1.9/IAlgebraV1_9NFT.sol';

/// @title ZapAlgebraSettler
/// @notice Adds liquidity to an Algebra V1.9 or Algebra Integral V1.0 position with the token
/// balances this contract holds, in an owner call of an allowance hub fulfillment
contract ZapAlgebraSettler is IZapAlgebraSettler, ZapUniswapV3Settler {
  constructor(address _WETH) ZapUniswapV3Settler(_WETH) {}

  /// @inheritdoc IZapAlgebraSettler
  function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data)
    external
  {
    _paySwapCallback(amount0Delta, amount1Delta, data);
  }

  /// @dev Mints a new position to the recipient with the given amounts
  function _mint(
    ZapInParams calldata params,
    address token0,
    address token1,
    uint256 amount0,
    uint256 amount1
  )
    internal
    virtual
    override
    returns (uint256 tokenId, uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    return IAlgebraV1_9NFT(params.posManager)
      .mint(
        IAlgebraV1_9NFT.MintParams({
          token0: token0,
          token1: token1,
          tickLower: params.tickLower,
          tickUpper: params.tickUpper,
          amount0Desired: amount0,
          amount1Desired: amount1,
          amount0Min: 0,
          amount1Min: 0,
          recipient: params.recipient,
          deadline: block.timestamp
        })
      );
  }
}
