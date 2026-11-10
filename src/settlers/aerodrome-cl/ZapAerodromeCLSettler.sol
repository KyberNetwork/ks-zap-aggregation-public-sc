// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ZapUniswapV3Settler} from '../uniswap-v3/ZapUniswapV3Settler.sol';

import {IAerodromeCLNFT} from '../../vendors/aerodrome-cl/IAerodromeCLNFT.sol';
import {IAerodromeCLPool} from '../../vendors/aerodrome-cl/IAerodromeCLPool.sol';
import {IUniswapV3Pool} from '../../vendors/uniswap-v3/IUniswapV3Pool.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

/// @title ZapAerodromeCLSettler
/// @notice Adds liquidity to an Aerodrome CL position with the token balances this contract holds,
/// in an owner call of an allowance hub fulfillment
contract ZapAerodromeCLSettler is ZapUniswapV3Settler {
  using Address for address;

  constructor(address _WETH) ZapUniswapV3Settler(_WETH) {}

  /// @dev Reads the leading price word of the `slot0` getter of the pool
  function _getSqrtPriceX96(address pool) internal view override returns (uint160 sqrtPriceX96) {
    bytes memory callData = abi.encodeWithSelector(IAerodromeCLPool.slot0.selector);
    bytes memory returnData = pool.functionStaticCall(callData);
    sqrtPriceX96 = uint160(uint256(bytes32(returnData)));
  }

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
