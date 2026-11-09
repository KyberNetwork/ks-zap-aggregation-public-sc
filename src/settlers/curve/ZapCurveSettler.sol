// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IKSGenericRouter} from '../../interfaces/IKSGenericRouter.sol';
import {IZapCurveSettler} from '../../interfaces/settlers/curve/IZapCurveSettler.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {ICurveStableSwap} from '../../vendors/curve/ICurveStableSwap.sol';
import {ICurveTricrypto} from '../../vendors/curve/ICurveTricrypto.sol';
import {ICurveTwocrypto} from '../../vendors/curve/ICurveTwocrypto.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/// @title ZapCurveSettler
/// @notice Adds liquidity to a Curve pool with the token balances this contract holds, in an owner
/// call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained.
contract ZapCurveSettler is IZapCurveSettler, ImmutableState {
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

    uint256 N_COINS;
    if (params.poolType == CurvePoolType.STABLESWAP_NG) {
      N_COINS = ICurveStableSwap(params.pool).N_COINS();
    } else if (params.poolType == CurvePoolType.TRICRYPTO) {
      N_COINS = 3;
    } else if (params.poolType == CurvePoolType.TWOCYCRYPTO) {
      N_COINS = 2;
    } else {
      revert InvalidCurvePoolType();
    }

    address[] memory tokens = new address[](N_COINS);
    bool hasWETH;
    for (uint256 i = 0; i < N_COINS; i++) {
      tokens[i] = ICurveStableSwap(params.pool).coins(i);
      if (tokens[i] == address(WETH)) {
        hasWETH = true;
      }
    }
    if (hasWETH) {
      WETH.wrapETH();
    }

    ZapInResult memory zapInResult;
    zapInResult.pool = params.pool;
    zapInResult.recipient = params.recipient;
    zapInResult.amounts = new uint256[](N_COINS);
    for (uint256 i = 0; i < N_COINS; i++) {
      tokens[i].forceApproveInf(params.pool);
      zapInResult.amounts[i] = tokens[i].selfBalanceMinusOne();
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
      zapInResult.liquidity = ICurveTwocrypto(params.pool)
        .add_liquidity([zapInResult.amounts[0], zapInResult.amounts[1]], params.minLiquidity);
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
