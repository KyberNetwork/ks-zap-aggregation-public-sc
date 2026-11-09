// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IKSGenericRouter} from '../../interfaces/IKSGenericRouter.sol';
import {
  IZapBalancerV3Settler
} from '../../interfaces/settlers/balancer-v3/IZapBalancerV3Settler.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {ICompositeLiquidityRouter} from '../../vendors/balancer-v3/ICompositeLiquidityRouter.sol';
import {IRouter} from '../../vendors/balancer-v3/IRouter.sol';

import {IAllowanceTransfer} from 'ks-common-sc/src/interfaces/IAllowanceTransfer.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {
  ReentrancyGuardTransient
} from 'openzeppelin-contracts/contracts/utils/ReentrancyGuardTransient.sol';

/// @title ZapBalancerV3Settler
/// @notice Adds liquidity to a Balancer V3 pool with the token balances this contract holds, in an
/// owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained.
contract ZapBalancerV3Settler is IZapBalancerV3Settler, ImmutableState, ReentrancyGuardTransient {
  using TokenHelper for address;
  using CommonLibrary for *;

  /// @dev The Permit2 contract that the router pulls tokens through
  IAllowanceTransfer internal immutable PERMIT2;

  constructor(address _WETH, address _permit2) ImmutableState(_WETH) {
    PERMIT2 = IAllowanceTransfer(_permit2);
  }

  /// @dev Allows the contract to receive native tokens
  receive() external payable {}

  /// @inheritdoc IKSGenericRouter
  function ksExecute(bytes calldata data) external payable nonReentrant returns (bytes memory) {
    ZapInParams calldata params;
    assembly ('memory-safe') {
      params := add(data.offset, calldataload(data.offset))
    }

    uint256 length = params.tokens.length;

    bool hasWETH;
    for (uint256 i = 0; i < length; i++) {
      if (params.tokens[i] == address(WETH)) {
        hasWETH = true;
      }
    }
    if (hasWETH) {
      WETH.wrapETH();
    }

    for (uint256 i = 0; i < length; i++) {
      if (params.approvalFlags.at(i)) {
        params.tokens[i].permit2ApproveInf(params.router, PERMIT2);
      }
    }

    uint256[] memory balances = new uint256[](length);
    for (uint256 i = 0; i < length; i++) {
      balances[i] = params.tokens[i].selfBalanceMinusOne();
    }

    ZapInResult memory zapInResult;
    zapInResult.pool = params.pool;
    zapInResult.recipient = params.recipient;

    if (params.wrapUnderlying.length > 0) {
      zapInResult.bptAmount = ICompositeLiquidityRouter(params.router)
        .addLiquidityUnbalancedToERC4626Pool(
          params.pool, params.wrapUnderlying, balances, params.minBptAmount, false, ''
        );
    } else {
      zapInResult.bptAmount = IRouter(params.router)
        .addLiquidityUnbalanced(params.pool, balances, params.minBptAmount, false, '');
    }

    params.pool.safeTransfer(params.recipient, zapInResult.bptAmount);

    zapInResult.remainingAmounts = new uint256[](length);
    for (uint256 i = 0; i < length; i++) {
      uint256 remainingAmount = params.tokens[i].selfBalanceMinusOne();
      zapInResult.remainingAmounts[i] = remainingAmount;
      if (remainingAmount > 0) {
        params.tokens[i].safeTransfer(params.refundRecipient, remainingAmount);
      }
    }

    bytes memory result = abi.encode(zapInResult);
    emit ZapIn(result);

    return result;
  }
}
