// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IKSZapExecutor} from '../../interfaces/IKSZapExecutor.sol';
import {IZapCurveSettler} from '../../interfaces/settlers/curve/IZapCurveSettler.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {ICurveStableSwap} from '../../vendors/curve/ICurveStableSwap.sol';
import {ICurveTricrypto} from '../../vendors/curve/ICurveTricrypto.sol';
import {ICurveTwocrypto} from '../../vendors/curve/ICurveTwocrypto.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/// @title ZapCurveSettler
/// @notice Adds liquidity to a Curve pool with the token balances this contract holds, when
/// KSZapRouterV3 delegatecalls it in an owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained. A pool
/// coin equal to the native address is supplied as native balance, which is forwarded as call value
/// to a TwoCrypto pool. WETH held by the contract is unwrapped for such a pool.
contract ZapCurveSettler is IZapCurveSettler, ImmutableState {
  using TokenHelper for address;
  using CommonLibrary for *;

  constructor(address _WETH) ImmutableState(_WETH) {}

  /// @dev Allows the contract to receive native tokens
  receive() external payable {}

  /// @inheritdoc IKSZapExecutor
  function executeZap(bytes calldata data) external payable returns (bytes memory) {
    ZapInParams calldata params;
    assembly ('memory-safe') {
      params := data.offset
    }

    uint256 N_COINS;
    if (params.poolType == CurvePoolType.STABLESWAP_NG) {
      N_COINS = ICurveStableSwap(params.pool).N_COINS();
    } else if (params.poolType == CurvePoolType.TRICRYPTO) {
      N_COINS = 3;
    } else {
      N_COINS = 2;
    }

    address[] memory tokens = new address[](N_COINS);
    bool hasWETH = false;
    bool hasNative = false;
    for (uint256 i = 0; i < N_COINS; i++) {
      tokens[i] = ICurveStableSwap(params.pool).coins(i);
      if (tokens[i] == address(WETH)) {
        hasWETH = true;
      } else if (tokens[i].isNative()) {
        hasNative = true;
      }
    }
    if (hasWETH) {
      WETH.wrapETH();
    } else if (hasNative) {
      WETH.unwrapWETH();
    }

    ZapInResult memory zapInResult;
    zapInResult.pool = params.pool;
    zapInResult.recipient = params.recipient;
    zapInResult.amounts = new uint256[](N_COINS);
    uint256 nativeValue = 0;
    for (uint256 i = 0; i < N_COINS; i++) {
      zapInResult.amounts[i] = tokens[i].selfBalanceMinusOne();
      if (tokens[i].isNative()) {
        nativeValue += zapInResult.amounts[i];
      } else {
        tokens[i].forceApproveInf(params.pool);
      }
    }

    if (params.poolType == CurvePoolType.STABLESWAP_NG) {
      zapInResult.liquidity =
        ICurveStableSwap(params.pool).add_liquidity(zapInResult.amounts, params.minLiquidity);
    } else if (params.poolType == CurvePoolType.TRICRYPTO) {
      zapInResult.liquidity = ICurveTricrypto(params.pool)
        .add_liquidity(
          [zapInResult.amounts[0], zapInResult.amounts[1], zapInResult.amounts[2]],
          params.minLiquidity
        );
    } else {
      zapInResult.liquidity = ICurveTwocrypto(params.pool).add_liquidity{value: nativeValue}(
        [zapInResult.amounts[0], zapInResult.amounts[1]], params.minLiquidity
      );
    }

    _getLpToken(params.pool).safeTransfer(params.recipient, zapInResult.liquidity);

    for (uint256 i = 0; i < N_COINS; i++) {
      uint256 remainingAmount = tokens[i].selfBalanceMinusOne();
      if (remainingAmount > 0) {
        tokens[i].safeTransfer(params.refundRecipient, remainingAmount);
      }
    }

    bytes memory result = abi.encode(zapInResult);
    emit ZapIn(result);

    return result;
  }

  /// @dev Returns the LP token of the pool, which is the pool itself when it has no `token` getter
  function _getLpToken(address pool) internal view returns (address) {
    bytes memory callData = abi.encodeCall(ICurveTricrypto.token, ());
    (bool success, bytes memory data) = pool.staticcall(callData);

    if (success && data.length == 32) {
      return abi.decode(data, (address));
    } else {
      return pool;
    }
  }
}
