// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {ZapALMVaultAdapter} from '../alm-vault/ZapALMVaultAdapter.sol';

import {ISteerVault} from '../../vendors/steer/ISteerVault.sol';

/// @title ZapSteerAdapter
/// @notice Deposits the token balances of the account that delegatecalls it into a Steer vault, or
/// removes vault shares that account holds
contract ZapSteerAdapter is ZapALMVaultAdapter {
  /// @param _WETH The wrapped native token
  constructor(address _WETH) ZapALMVaultAdapter(_WETH) {}

  /// @dev Deposits the amounts in `state` into the vault, which mints the shares to the recipient
  /// and leaves the amounts it does not use
  function _deposit(ZapInOwnerParams calldata params, ZapInState memory state)
    internal
    override
    returns (uint256 shares, uint256 addedAmount0, uint256 addedAmount1)
  {
    (shares, addedAmount0, addedAmount1) = ISteerVault(params.vault)
      .deposit(state.amount0, state.amount1, 0, 0, params.recipient);
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

  /// @dev Burns the shares of the proxy through the vault, which transfers the tokens to the proxy
  function _withdraw(RemoveOwnerParams calldata params) internal override {
    ISteerVault(params.vault).withdraw(params.shares, 0, 0, address(this));
  }
}
