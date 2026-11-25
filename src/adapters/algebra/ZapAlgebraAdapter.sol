// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ZapUniswapV3Adapter} from '../uniswap-v3/ZapUniswapV3Adapter.sol';

import {IAlgebraV1_9BasePool} from '../../vendors/algebra-v1.9/IAlgebraV1_9BasePool.sol';
import {IAlgebraV1_9NFT} from '../../vendors/algebra-v1.9/IAlgebraV1_9NFT.sol';

/// @title ZapAlgebraAdapter
/// @notice Adds liquidity to an Algebra V1.9 or Algebra Integral V1.0 position with the token
/// balances of the account that delegatecalls it, or removes liquidity from a position that
/// account holds
contract ZapAlgebraAdapter is ZapUniswapV3Adapter {
  /// @param _WETH The wrapped native token
  constructor(address _WETH) ZapUniswapV3Adapter(_WETH) {}

  /// @dev Staticcalls the `globalState` getter of the pool and returns the first word of its
  /// return data, the sqrt price. Reverts with the return data of the pool when the call fails or
  /// returns less than one word.
  function _getSqrtPriceX96(address pool)
    internal
    view
    virtual
    override
    returns (uint160 sqrtPriceX96)
  {
    bytes4 selector = IAlgebraV1_9BasePool.globalState.selector;
    assembly ('memory-safe') {
      mstore(0, selector)
      let success := staticcall(gas(), pool, 0, 4, 0, 0x20)
      if or(iszero(success), lt(returndatasize(), 0x20)) {
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
      sqrtPriceX96 := mload(0)
    }
  }

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
