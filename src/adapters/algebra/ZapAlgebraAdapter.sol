// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ZapUniswapV3Adapter} from '../uniswap-v3/ZapUniswapV3Adapter.sol';

import {IAlgebraV1_9NFT} from '../../vendors/algebra-v1.9/IAlgebraV1_9NFT.sol';

/// @title ZapAlgebraAdapter
/// @notice Adds liquidity to an Algebra V1.9 or Algebra Integral V1.0 position with the token
/// balances of the account that delegatecalls it, or removes liquidity from a position that
/// account holds
contract ZapAlgebraAdapter is ZapUniswapV3Adapter {
  /// @param _WETH The wrapped native token
  constructor(address _WETH) ZapUniswapV3Adapter(_WETH) {}

  /// @dev Mints a new position to the recipient with the amounts in `state`
  function _mint(ZapInOwnerParams calldata params, ZapInState memory state)
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
