// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ZapArrakisV2Settler} from '../arrakis-v2/ZapArrakisV2Settler.sol';

import {ISteerVault} from '../../vendors/steer/ISteerVault.sol';

/// @title ZapSteerSettler
/// @notice Deposits into a Steer vault with the token balances this contract holds, when
/// KSZapRouterV3 delegatecalls it in an owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained. The
/// swap callbacks of the zap again are forwarded to the helper.
contract ZapSteerSettler is ZapArrakisV2Settler {
  constructor(address _WETH) ZapArrakisV2Settler(_WETH) {}

  /// @dev Deposits the given amounts into the Steer vault, minting the shares to the recipient
  function _deposit(ZapInParams calldata params, ZapInState memory state)
    internal
    override
    returns (uint256 shares, uint256 addedAmount0, uint256 addedAmount1)
  {
    (shares, addedAmount0, addedAmount1) = ISteerVault(params.vault)
      .deposit(state.amount0, state.amount1, 0, 0, params.recipient);
  }

  /// @dev Returns the vault, which pulls the tokens of the deposit
  function _approveTarget(ZapInParams calldata params) internal pure override returns (address) {
    return params.vault;
  }
}
