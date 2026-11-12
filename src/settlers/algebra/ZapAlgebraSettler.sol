// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {ZapUniswapV3Settler} from '../uniswap-v3/ZapUniswapV3Settler.sol';

import {IAlgebraV1_9BasePool} from '../../vendors/algebra-v1.9/IAlgebraV1_9BasePool.sol';
import {IAlgebraV1_9NFT} from '../../vendors/algebra-v1.9/IAlgebraV1_9NFT.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

/// @title ZapAlgebraSettler
/// @notice Adds liquidity to an Algebra V1.9 or Algebra Integral V1.0 position with the token
/// balances this contract holds, when KSZapRouterV3 delegatecalls it in an owner call of an
/// allowance hub fulfillment
contract ZapAlgebraSettler is ZapUniswapV3Settler {
  using Address for address;

  constructor(address _WETH) ZapUniswapV3Settler(_WETH) {}

  /// @dev Reads the leading price word of the `globalState` getter of the pool
  function _getSqrtPriceX96(address pool)
    internal
    view
    virtual
    override
    returns (uint160 sqrtPriceX96)
  {
    bytes memory callData = abi.encodeWithSelector(IAlgebraV1_9BasePool.globalState.selector);
    bytes memory returnData = pool.functionStaticCall(callData);
    assembly ('memory-safe') {
      sqrtPriceX96 := mload(add(returnData, 0x20))
    }
  }

  /// @dev Mints a new position to the recipient with the given amounts
  function _mint(ZapInParams calldata params, ZapInState memory state)
    internal
    virtual
    override
    returns (uint256 tokenId, uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    return IAlgebraV1_9NFT(params.posManager)
      .mint(
        IAlgebraV1_9NFT.MintParams({
          token0: state.token0,
          token1: state.token1,
          tickLower: params.tickLower,
          tickUpper: params.tickUpper,
          amount0Desired: state.amount0,
          amount1Desired: state.amount1,
          amount0Min: 0,
          amount1Min: 0,
          recipient: params.recipient,
          deadline: block.timestamp
        })
      );
  }
}
