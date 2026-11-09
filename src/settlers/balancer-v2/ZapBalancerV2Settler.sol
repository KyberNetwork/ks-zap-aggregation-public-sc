// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IKSGenericRouter} from '../../interfaces/IKSGenericRouter.sol';
import {
  IZapBalancerV2Settler
} from '../../interfaces/settlers/balancer-v2/IZapBalancerV2Settler.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {IVault} from '../../vendors/balancer-v2/IVault.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

/// @title ZapBalancerV2Settler
/// @notice Adds liquidity to a Balancer V2 pool with the token balances this contract holds, in an
/// owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained.
contract ZapBalancerV2Settler is IZapBalancerV2Settler, ImmutableState {
  using TokenHelper for address;
  using CommonLibrary for *;

  constructor(address _WETH) ImmutableState(_WETH) {}

  /// @dev Allows the contract to receive native tokens
  receive() external payable {}

  /// @inheritdoc IKSGenericRouter
  function ksExecute(bytes calldata data) external payable returns (bytes memory) {
    ZapInParams calldata params;
    assembly ('memory-safe') {
      params := data.offset
    }

    (address[] memory poolTokens,,) = IVault(params.vault).getPoolTokens(params.poolId);
    uint256 length = poolTokens.length;

    bool hasWETH;
    for (uint256 i = 0; i < length; i++) {
      if (poolTokens[i] == address(WETH)) {
        hasWETH = true;
      }
    }
    if (hasWETH) {
      WETH.wrapETH();
    }

    for (uint256 i = 0; i < length; i++) {
      if (params.approvalFlags.at(i)) {
        poolTokens[i].forceApproveInf(params.vault);
      }
    }

    uint256[] memory currentBalances = new uint256[](length);
    uint256[] memory maxAmountsIn = new uint256[](length);
    for (uint256 i = 0; i < length; i++) {
      currentBalances[i] = poolTokens[i].selfBalanceMinusOne();
      maxAmountsIn[i] = type(uint256).max;
    }

    IVault.JoinPoolRequest memory joinRequest = IVault.JoinPoolRequest({
      assets: poolTokens,
      maxAmountsIn: maxAmountsIn,
      userData: abi.encode(
        IVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, currentBalances, params.minBptAmount
      ),
      fromInternalBalance: false
    });

    ZapInResult memory zapInResult;
    zapInResult.vault = params.vault;
    zapInResult.poolId = params.poolId;
    zapInResult.recipient = params.recipient;

    (address pool,) = IVault(params.vault).getPool(params.poolId);
    uint256 bptBefore = IERC20(pool).balanceOf(params.recipient);
    IVault(params.vault).joinPool(params.poolId, address(this), params.recipient, joinRequest);
    zapInResult.bptAmount = IERC20(pool).balanceOf(params.recipient) - bptBefore;

    zapInResult.remainingAmounts = new uint256[](length);
    for (uint256 i = 0; i < length; i++) {
      uint256 remainingAmount = poolTokens[i].selfBalanceMinusOne();
      zapInResult.remainingAmounts[i] = remainingAmount;
      if (remainingAmount > 0) {
        poolTokens[i].safeTransfer(params.refundRecipient, remainingAmount);
      }
    }

    bytes memory result = abi.encode(zapInResult);
    emit ZapIn(result);

    return result;
  }
}
