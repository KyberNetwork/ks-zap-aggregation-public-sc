// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {ZapAlgebraSettler} from '../../algebra/ZapAlgebraSettler.sol';

import {
  IAlgebraIntegralV1_2NFT
} from '../../../vendors/algebra-integral/v1.2/IAlgebraIntegralV1_2NFT.sol';
import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';

/**
 * @title ZapAlgebraIntegralV1_2Settler
 * @notice Adds liquidity to an Algebra Integral V1.2 position with the token balances this
 * contract holds, when KSZapRouterV3 delegatecalls it in an owner call of an allowance hub
 * fulfillment
 * @dev `ZapInParams.extraData` is the ABI-encoded deployer of the pool
 */
contract ZapAlgebraIntegralV1_2Settler is ZapAlgebraSettler {
  using CalldataDecoder for bytes;

  constructor(address _WETH) ZapAlgebraSettler(_WETH) {}

  /// @dev Mints a new position to the recipient with the given amounts for the pool of the
  /// deployer in `params.extraData`
  function _mint(ZapInParams calldata params, ZapInState memory state)
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
