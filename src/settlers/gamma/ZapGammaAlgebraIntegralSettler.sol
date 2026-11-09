// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ZapGammaSettler} from './ZapGammaSettler.sol';

import {IUniProxyETH} from '../../vendors/gamma/IUniProxyETH.sol';

import {CommonLibrary} from '../../libraries/CommonLibrary.sol';

/// @title ZapGammaAlgebraIntegralSettler
/// @notice Deposits into a Gamma vault on Algebra Integral with the token balances this contract
/// holds, in an owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained. The
/// swap callbacks of the zap again are forwarded to the helper.
contract ZapGammaAlgebraIntegralSettler is ZapGammaSettler {
  using CommonLibrary for *;

  /// @dev The maximum slippage of the deposit, in basis points
  uint256 internal constant MAX_SLIPPAGE_BPS = 10_000;

  constructor(address _WETH) ZapGammaSettler(_WETH) {}

  /// @dev Deposits the given amounts through the UniProxy, minting the shares to the recipient
  function _deposit(ZapInParams calldata params, ZapInState memory state)
    internal
    override
    returns (uint256 shares, uint256 addedAmount0, uint256 addedAmount1)
  {
    shares = IUniProxyETH(params.router)
      .deposit(
        state.amount0,
        state.amount1,
        params.recipient,
        params.vault,
        [uint256(0), 0, 0, 0],
        MAX_SLIPPAGE_BPS
      );

    addedAmount0 = state.amount0 - state.token0.selfBalanceMinusOne();
    addedAmount1 = state.amount1 - state.token1.selfBalanceMinusOne();
  }
}
