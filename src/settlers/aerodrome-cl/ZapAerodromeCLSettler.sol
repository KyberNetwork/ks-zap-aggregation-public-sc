// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ZapUniswapV3Settler} from '../uniswap-v3/ZapUniswapV3Settler.sol';

import {IAerodromeCLNFT} from '../../vendors/aerodrome-cl/IAerodromeCLNFT.sol';
import {IUniswapV3Pool} from '../../vendors/uniswap-v3/IUniswapV3Pool.sol';

/// @title ZapAerodromeCLSettler
/// @notice Adds liquidity to an Aerodrome CL position with the token balances this contract holds,
/// in an owner call of an allowance hub fulfillment
contract ZapAerodromeCLSettler is ZapUniswapV3Settler {
  constructor(address _WETH) ZapUniswapV3Settler(_WETH) {}

  /// @dev Mints a new position to the recipient with the given amounts at the tick spacing of the
  /// pool
  function _mint(
    ZapInParams calldata params,
    address token0,
    address token1,
    uint256 amount0,
    uint256 amount1
  )
    internal
    override
    returns (uint256 tokenId, uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    return IAerodromeCLNFT(params.posManager)
      .mint(
        IAerodromeCLNFT.MintParams({
          token0: token0,
          token1: token1,
          tickSpacing: IUniswapV3Pool(params.pool).tickSpacing(),
          tickLower: params.tickLower,
          tickUpper: params.tickUpper,
          amount0Desired: amount0,
          amount1Desired: amount1,
          amount0Min: 0,
          amount1Min: 0,
          recipient: params.recipient,
          deadline: block.timestamp,
          sqrtPriceX96: 0
        })
      );
  }
}
