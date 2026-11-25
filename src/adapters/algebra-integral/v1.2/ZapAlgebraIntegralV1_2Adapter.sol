// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {ZapAlgebraAdapter} from '../../algebra/ZapAlgebraAdapter.sol';

import {
  IAlgebraIntegralV1_2NFT
} from '../../../vendors/algebra-integral/v1.2/IAlgebraIntegralV1_2NFT.sol';
import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';

/**
 * @title ZapAlgebraIntegralV1_2Adapter
 * @notice Adds liquidity to an Algebra Integral V1.2 position with the token balances of the
 * account that delegatecalls it, or removes liquidity from a position that account holds
 * @dev `ZapInOwnerParams.extraData` is the ABI-encoded address of the deployer of the pool
 */
contract ZapAlgebraIntegralV1_2Adapter is ZapAlgebraAdapter {
  using CalldataDecoder for bytes;

  /// @param _WETH The wrapped native token
  constructor(address _WETH) ZapAlgebraAdapter(_WETH) {}

  /// @dev Mints a new position to the recipient with the amounts in `state` for the pool of the
  /// deployer in `params.extraData`
  function _mint(ZapInOwnerParams calldata params, ZapInState memory state)
    internal
    override
    returns (uint256 tokenId, uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    address deployer = params.extraData.decodeAddress();

    return IAlgebraIntegralV1_2NFT(params.posManager)
      .mint(
        IAlgebraIntegralV1_2NFT.MintParams({
          token0: state.token0,
          token1: state.token1,
          deployer: deployer,
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
