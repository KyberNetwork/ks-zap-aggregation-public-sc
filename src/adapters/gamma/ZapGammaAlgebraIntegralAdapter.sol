// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {ZapGammaAdapter} from './ZapGammaAdapter.sol';

import {IUniProxyETH} from '../../vendors/gamma/IUniProxyETH.sol';

/// @title ZapGammaAlgebraIntegralAdapter
/// @notice Deposits the token balances of the account that delegatecalls it into a Gamma vault on
/// Algebra Integral, or removes vault shares that account holds
contract ZapGammaAlgebraIntegralAdapter is ZapGammaAdapter {
  /// @dev The maximum slippage of the deposit, in basis points
  uint256 internal constant MAX_SLIPPAGE_BPS = 10_000;

  /// @param _WETH The wrapped native token
  constructor(address _WETH) ZapGammaAdapter(_WETH) {}

  /// @dev Calls the deposit of the UniProxy for Algebra Integral with the amounts in `state` and
  /// the maximum slippage, and returns the shares
  function _depositThroughProxy(ZapInOwnerParams calldata params, ZapInState memory state)
    internal
    override
    returns (uint256 shares)
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
  }
}
