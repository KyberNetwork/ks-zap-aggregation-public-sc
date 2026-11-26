// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ZapVaultAdapter} from '../vault/ZapVaultAdapter.sol';

import {IHypervisor} from '../../vendors/gamma/IHypervisor.sol';
import {IUniProxy} from '../../vendors/gamma/IUniProxy.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/// @title ZapGammaAdapter
/// @notice Deposits the token balances of the account that delegatecalls it into a Gamma vault on
/// Uniswap V3, Algebra Base, Algebra Directional Fees or Ramses V2, or removes vault shares that
/// account holds
contract ZapGammaAdapter is ZapVaultAdapter {
  using TokenHelper for address;

  /// @param _WETH The wrapped native token
  constructor(address _WETH) ZapVaultAdapter(_WETH) {}

  /// @dev Deposits the amounts in `state` through the UniProxy, which mints the shares to the
  /// recipient; the deposited amounts are the balance decreases of the deposit
  function _deposit(ZapInOwnerParams calldata params, ZapInState memory state)
    internal
    override
    returns (uint256 shares, uint256 addedAmount0, uint256 addedAmount1)
  {
    uint256 balance0Before = state.token0.selfBalance();
    uint256 balance1Before = state.token1.selfBalance();

    shares = _depositThroughProxy(params, state);

    addedAmount0 = balance0Before - state.token0.selfBalance();
    addedAmount1 = balance1Before - state.token1.selfBalance();
  }

  /// @dev Calls the deposit of the UniProxy with the amounts in `state` and returns the shares
  function _depositThroughProxy(ZapInOwnerParams calldata params, ZapInState memory state)
    internal
    virtual
    returns (uint256 shares)
  {
    shares = IUniProxy(params.router)
      .deposit(state.amount0, state.amount1, params.recipient, params.vault, [uint256(0), 0, 0, 0]);
  }

  /// @dev Returns the vault, which pulls the tokens of the deposit
  function _approveTarget(ZapInOwnerParams calldata params)
    internal
    pure
    override
    returns (address)
  {
    return params.vault;
  }

  /// @dev Burns the shares of the proxy through the hypervisor, which transfers the tokens to the
  /// proxy
  function _withdraw(RemoveOwnerParams calldata params) internal override {
    uint256[4] memory minAmounts;
    IHypervisor(params.vault).withdraw(params.shares, address(this), address(this), minAmounts);
  }
}
