// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {ZapUniswapV3Adapter} from '../uniswap-v3/ZapUniswapV3Adapter.sol';

import {IAerodromeCLNFT} from '../../vendors/aerodrome-cl/IAerodromeCLNFT.sol';
import {IUniswapV3Pool} from '../../vendors/uniswap-v3/IUniswapV3Pool.sol';

/// @title ZapAerodromeCLAdapter
/// @notice Adds liquidity to an Aerodrome CL position with the token balances of the account that
/// delegatecalls it, or removes liquidity from a position that account holds
contract ZapAerodromeCLAdapter is ZapUniswapV3Adapter {
  /// @param _WETH The wrapped native token
  constructor(address _WETH) ZapUniswapV3Adapter(_WETH) {}

  /// @dev Mints a new position to the recipient with the amounts in `state` at the tick spacing of
  /// the pool
  function _mint(ZapInOwnerParams calldata params, ZapInState memory state)
    internal
    override
    returns (uint256 tokenId, uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    return IAerodromeCLNFT(params.posManager)
      .mint(
        IAerodromeCLNFT.MintParams({
          token0: state.token0,
          token1: state.token1,
          tickSpacing: IUniswapV3Pool(params.pool).tickSpacing(),
          tickLower: params.tickLower,
          tickUpper: params.tickUpper,
          amount0Desired: state.amount0,
          amount1Desired: state.amount1,
          amount0Min: 0,
          amount1Min: 0,
          recipient: params.recipient,
          deadline: block.timestamp,
          sqrtPriceX96: 0
        })
      );
  }
}
