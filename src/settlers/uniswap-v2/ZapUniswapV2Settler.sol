// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IKSZapExecutor} from '../../interfaces/IKSZapExecutor.sol';
import {IZapUniswapV2Settler} from '../../interfaces/settlers/uniswap-v2/IZapUniswapV2Settler.sol';

import {AddLiquidityPreviewHelperCaller} from '../../base/AddLiquidityPreviewHelperCaller.sol';
import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapAgainHelperCaller} from '../../base/ZapAgainHelperCaller.sol';
import {AddLiquidityPreviewRecord} from '../../libraries/AddLiquidityPreviewRecord.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {IUniswapV2Pair} from '../../vendors/uniswap-v2/IUniswapV2Pair.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/// @title ZapUniswapV2Settler
/// @notice Adds liquidity to a Uniswap V2 pair with the token balances this contract holds, when
/// KSZapRouterV3 delegatecalls it in an owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained.
contract ZapUniswapV2Settler is
  IZapUniswapV2Settler,
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

    ZapInState memory state;
    state.token0 = IUniswapV2Pair(params.pool).token0();
    state.token1 = IUniswapV2Pair(params.pool).token1();

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

    bytes memory fixedParams = abi.encode(
      ZapInFixedParams({
        pool: params.pool,
        swapFee: params.swapFee,
        protocolFee: params.protocolFee,
        feeDenominator: params.feeDenominator,
        readBalanceFlag: params.readBalanceFlag,
        optimizer: address(0),
        optimizeFixedParams: ''
      })
    );

    _mint(params, state, zapInResult, fixedParams);

    if (
      state.amount0 >= params.minZapInAmounts.value0()
        || state.amount1 >= params.minZapInAmounts.value1()
    ) {
      _zapAgain(params, state, zapInResult, fixedParams);
    }

    require(zapInResult.liquidity >= params.minLiquidity, ZapInUniswapV2InsufficientLiquidity());

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

  /// @dev Transfers the amounts that the helper previews to the pair, mints to the recipient and
  /// records the minted liquidity and the added amounts in `zapInResult`
  function _mint(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult,
    bytes memory fixedParams
  ) internal {
    PreviewAddLiquidityResult memory preview = _preview(params, state, fixedParams);

    if (preview.liquidity == 0) {
      return;
    }

    state.token0.safeTransfer(params.pool, preview.addedAmount0);
    state.token1.safeTransfer(params.pool, preview.addedAmount1);
    uint256 liquidity = IUniswapV2Pair(params.pool).mint(params.recipient);

    unchecked {
      if (params.readBalanceFlag) {
        state.amount0 = state.token0.selfBalanceMinusOne();
        state.amount1 = state.token1.selfBalanceMinusOne();
      } else {
        state.amount0 -= preview.addedAmount0;
        state.amount1 -= preview.addedAmount1;
      }

      zapInResult.liquidity += liquidity;
      zapInResult.addedAmount0 += preview.addedAmount0;
      zapInResult.addedAmount1 += preview.addedAmount1;
    }
  }

  /// @dev Returns the preview that the last pool swap recorded, or queries `previewAddLiquidity`
  /// of the helper when no record exists
  function _preview(ZapInParams calldata params, ZapInState memory state, bytes memory fixedParams)
    internal
    returns (PreviewAddLiquidityResult memory preview)
  {
    (preview.liquidity, preview.addedAmount0, preview.addedAmount1) =
      AddLiquidityPreviewRecord.consume();
    if (preview.liquidity != 0) return preview;

    bytes memory variableParams =
      abi.encode(PreviewZapInVariableParams({amount0: state.amount0, amount1: state.amount1}));
    preview = abi.decode(
      _previewAddLiquidity(params.helper, fixedParams, variableParams), (PreviewAddLiquidityResult)
    );
  }

  /// @dev Swaps the remaining amounts through the helper and mints them into the pair
  function _zapAgain(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult,
    bytes memory fixedParams
  ) internal {
    bytes memory variableParams = abi.encode(PoolSwapVariableParams({extraData: ''}));

    PoolSwapResult memory swapResult =
      abi.decode(_poolSwap(params.helper, fixedParams, variableParams), (PoolSwapResult));

    state.amount0 = swapResult.amount0;
    state.amount1 = swapResult.amount1;

    _mint(params, state, zapInResult, fixedParams);
  }
}
