// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ZapArrakisV2Settler} from '../arrakis-v2/ZapArrakisV2Settler.sol';

import {IUniProxy} from '../../vendors/gamma/IUniProxy.sol';

import {CommonLibrary} from '../../libraries/CommonLibrary.sol';

/// @title ZapGammaSettler
/// @notice Deposits into a Gamma vault on Uniswap V3, Algebra Base, Algebra Directional Fees or
/// Ramses V2 with the token balances this contract holds, when KSZapRouterV3 delegatecalls it in an
/// owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained. The
/// swap callbacks of the zap again are forwarded to the helper.
contract ZapGammaSettler is ZapArrakisV2Settler {
  using CommonLibrary for *;

  constructor(address _WETH) ZapArrakisV2Settler(_WETH) {}

  /// @dev Deposits the given amounts through the UniProxy, minting the shares to the recipient
  function _deposit(ZapInParams calldata params, ZapInState memory state)
    internal
    virtual
    override
    returns (uint256 shares, uint256 addedAmount0, uint256 addedAmount1)
  {
    shares = IUniProxy(params.router)
      .deposit(state.amount0, state.amount1, params.recipient, params.vault, [uint256(0), 0, 0, 0]);

    addedAmount0 = state.amount0 - state.token0.selfBalanceMinusOne();
    addedAmount1 = state.amount1 - state.token1.selfBalanceMinusOne();
  }

  /// @dev Returns the vault, which pulls the tokens of the deposit
  function _approveTarget(ZapInParams calldata params) internal pure override returns (address) {
    return params.vault;
  }
}
