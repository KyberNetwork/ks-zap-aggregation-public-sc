// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IKSZapExecutor} from '../../interfaces/IKSZapExecutor.sol';
import {IZapPoolSwapAgainHelper} from '../../interfaces/settlers/IZapPoolSwapAgainHelper.sol';
import {IZapSolidlyV2Settler} from '../../interfaces/settlers/solidly-v2/IZapSolidlyV2Settler.sol';

import {AddLiquidityPreviewHelperCaller} from '../../base/AddLiquidityPreviewHelperCaller.sol';
import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapAgainHelperCaller} from '../../base/ZapAgainHelperCaller.sol';
import {AddLiquidityPreviewRecord} from '../../libraries/AddLiquidityPreviewRecord.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {ZapAgainRecord} from '../../libraries/ZapAgainRecord.sol';
import {ISolidlyV2Pair} from '../../vendors/solidly-v2/ISolidlyV2Pair.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/// @title ZapSolidlyV2Settler
/// @notice Adds liquidity to a Solidly V2 pair with the token balances this contract holds, when
/// KSZapRouterV3 delegatecalls it in an owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained. The
/// contract serves every Solidly V2 fork through the helper of that fork. The zap again runs when
/// the preceding pool swap of the solver recorded zap again parameters and the owner-signed helper
/// is set; the helper then swaps the remaining balances and returns the liquidity to add.
contract ZapSolidlyV2Settler is
  IZapSolidlyV2Settler,
  ImmutableState,
  AddLiquidityPreviewHelperCaller,
  ZapAgainHelperCaller
{
  using TokenHelper for address;
  using CommonLibrary for *;

  /// @dev Tokens and amounts of a zap in
  struct ZapInState {
    address token0;
    address token1;
    uint256 amount0;
    uint256 amount1;
  }

  constructor(address _WETH) ImmutableState(_WETH) {}

  /// @dev Allows the contract to receive native tokens
  receive() external payable {}

  /// @inheritdoc IKSZapExecutor
  function executeZap(bytes calldata data) external payable returns (bytes memory) {
    ZapInParams calldata params;
    assembly ('memory-safe') {
      params := data.offset
    }

    bytes memory zapAgainParams = ZapAgainRecord.load();

    ZapInState memory state;
    state.token0 = ISolidlyV2Pair(params.pool).token0();
    state.token1 = ISolidlyV2Pair(params.pool).token1();

    if (state.token0 == address(WETH) || state.token1 == address(WETH)) {
      WETH.wrapETH();
    }

    state.amount0 = state.token0.selfBalanceMinusOne();
    state.amount1 = state.token1.selfBalanceMinusOne();

    ZapInResult memory zapInResult;
    zapInResult.pool = params.pool;
    zapInResult.recipient = params.recipient;
    zapInResult.originalAmount0 = state.amount0;
    zapInResult.originalAmount1 = state.amount1;

    PreviewAddLiquidityResult memory preview = _preview(params, state);
    _mint(params, state, zapInResult, preview);

    if (zapAgainParams.length != 0 && params.helper != address(0)) {
      _zapAgain(params, state, zapInResult, zapAgainParams);
    }

    require(zapInResult.liquidity >= params.minLiquidity, ZapInSolidlyV2InsufficientLiquidity());

    zapInResult.remainingAmount0 = state.token0.selfBalanceMinusOne();
    if (zapInResult.remainingAmount0 > 0) {
      state.token0.safeTransfer(params.refundRecipient, zapInResult.remainingAmount0);
    }

    zapInResult.remainingAmount1 = state.token1.selfBalanceMinusOne();
    if (zapInResult.remainingAmount1 > 0) {
      state.token1.safeTransfer(params.refundRecipient, zapInResult.remainingAmount1);
    }

    bytes memory result = abi.encode(zapInResult);
    emit ZapIn(result);

    return result;
  }

  /// @dev Transfers the previewed amounts to the pair, mints to the recipient and records the
  /// minted liquidity and the added amounts in `zapInResult`
  function _mint(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult,
    PreviewAddLiquidityResult memory preview
  ) internal {
    if (preview.liquidity == 0) {
      return;
    }

    state.token0.safeTransfer(params.pool, preview.addedAmount0);
    state.token1.safeTransfer(params.pool, preview.addedAmount1);
    uint256 liquidity = ISolidlyV2Pair(params.pool).mint(params.recipient);

    unchecked {
      zapInResult.liquidity += liquidity;
      zapInResult.addedAmount0 += preview.addedAmount0;
      zapInResult.addedAmount1 += preview.addedAmount1;
    }
  }

  /// @dev Returns the preview that the last pool swap recorded, or queries `previewAddLiquidity`
  /// of the helper when no record exists
  function _preview(ZapInParams calldata params, ZapInState memory state)
    internal
    returns (PreviewAddLiquidityResult memory preview)
  {
    (preview.liquidity, preview.addedAmount0, preview.addedAmount1) =
      AddLiquidityPreviewRecord.load();
    if (preview.liquidity != 0) return preview;

    bytes memory fixedParams =
      abi.encode(ZapInFixedParams({pool: params.pool, readBalanceFlag: false}));
    bytes memory variableParams =
      abi.encode(PreviewZapInVariableParams({amount0: state.amount0, amount1: state.amount1}));
    preview = abi.decode(
      _previewAddLiquidity(params.helper, fixedParams, variableParams), (PreviewAddLiquidityResult)
    );
  }

  /// @dev Swaps the remaining amounts through the helper with the zap again parameters that the
  /// solver recorded and mints the liquidity that the helper returns into the pair
  function _zapAgain(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult,
    bytes memory zapAgainParams
  ) internal {
    ZapAgainParams memory again = abi.decode(zapAgainParams, (ZapAgainParams));

    bytes memory fixedParams =
      abi.encode(ZapInFixedParams({pool: params.pool, readBalanceFlag: again.readBalanceFlag}));

    IZapPoolSwapAgainHelper.PoolSwapAgainResult memory result =
      _poolSwapAgain(params.helper, fixedParams, again.minZapInAmounts);

    PreviewAddLiquidityResult memory preview = PreviewAddLiquidityResult({
      liquidity: result.liquidity,
      addedAmount0: result.addedAmount0,
      addedAmount1: result.addedAmount1
    });
    _mint(params, state, zapInResult, preview);
  }
}
