// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IKSGenericRouter} from '../../interfaces/IKSGenericRouter.sol';
import {IZapPairPreviewHelper} from '../../interfaces/settlers/IZapPairPreviewHelper.sol';
import {IZapPreviewHelper} from '../../interfaces/settlers/IZapPreviewHelper.sol';
import {IZapBrownFiV3Settler} from '../../interfaces/settlers/brownfi-v3/IZapBrownFiV3Settler.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {IBrownFiV3Pair} from '../../vendors/brownfi-v3/IBrownFiV3Pair.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {
  ReentrancyGuardTransient
} from 'openzeppelin-contracts/contracts/utils/ReentrancyGuardTransient.sol';

/// @title ZapBrownFiV3Settler
/// @notice Adds liquidity to a BrownFi V3 pair with the token balances this contract holds, in an
/// owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained.
contract ZapBrownFiV3Settler is IZapBrownFiV3Settler, ImmutableState, ReentrancyGuardTransient {
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

  /// @inheritdoc IKSGenericRouter
  function ksExecute(bytes calldata data) external payable nonReentrant returns (bytes memory) {
    ZapInParams calldata params;
    assembly ('memory-safe') {
      params := data.offset
    }

    ZapInState memory state;
    state.token0 = IBrownFiV3Pair(params.pool).token0();
    state.token1 = IBrownFiV3Pair(params.pool).token1();

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

    bytes memory fixedParams =
      abi.encode(ZapInFixedParams({pool: params.pool, iterations: params.iterations}));

    _mint(params, state, zapInResult, fixedParams);

    if (
      state.amount0 >= params.minZapInAmounts.value0()
        || state.amount1 >= params.minZapInAmounts.value1()
    ) {
      _zapAgain(params, state, zapInResult, fixedParams);
    }

    require(zapInResult.liquidity >= params.minLiquidity, ZapInBrownFiV3InsufficientLiquidity());

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

  /// @dev Mints the amounts the helper previews for the amounts in `state`
  function _mint(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult,
    bytes memory fixedParams
  ) internal {
    IZapPairPreviewHelper.PreviewMintResult memory preview = abi.decode(
      IZapPairPreviewHelper(params.helper)
        .previewMint(
          fixedParams,
          abi.encode(PreviewZapInVariableParams({amount0: state.amount0, amount1: state.amount1}))
        ),
      (IZapPairPreviewHelper.PreviewMintResult)
    );

    _mintAmounts(
      params, state, zapInResult, preview.liquidity, preview.addedAmount0, preview.addedAmount1
    );
  }

  /// @dev Transfers the given amounts to the pair, mints the liquidity and records the addition in
  /// `zapInResult`
  function _mintAmounts(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult,
    uint256 liquidity,
    uint256 addedAmount0,
    uint256 addedAmount1
  ) internal {
    if (liquidity == 0) {
      return;
    }

    state.token0.safeTransfer(params.pool, addedAmount0);
    state.token1.safeTransfer(params.pool, addedAmount1);
    liquidity = IBrownFiV3Pair(params.pool).mint(params.recipient);

    state.amount0 = state.token0.selfBalanceMinusOne();
    state.amount1 = state.token1.selfBalanceMinusOne();

    unchecked {
      zapInResult.liquidity += liquidity;
      zapInResult.addedAmount0 += addedAmount0;
      zapInResult.addedAmount1 += addedAmount1;
    }
  }

  /// @dev Swaps the remaining amounts as the helper previews and mints them into the pair
  function _zapAgain(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult,
    bytes memory fixedParams
  ) internal {
    PreviewZapInResult memory preview = abi.decode(
      IZapPreviewHelper(params.helper)
        .previewZapIn(
          fixedParams,
          abi.encode(PreviewZapInVariableParams({amount0: state.amount0, amount1: state.amount1}))
        ),
      (PreviewZapInResult)
    );

    if (preview.amount0Delta < 0 || preview.amount1Delta < 0) {
      bool zeroForOne = preview.amount0Delta < 0;
      (address tokenIn, uint256 swappedAmount, uint256 returnedAmount) = zeroForOne
        ? (state.token0, uint256(-preview.amount0Delta), uint256(preview.amount1Delta))
        : (state.token1, uint256(-preview.amount1Delta), uint256(preview.amount0Delta));

      tokenIn.safeTransfer(params.pool, swappedAmount);
      IBrownFiV3Pair(params.pool)
        .swap(zeroForOne ? 0 : returnedAmount, zeroForOne ? returnedAmount : 0, address(this));

      state.amount0 = state.token0.selfBalanceMinusOne();
      state.amount1 = state.token1.selfBalanceMinusOne();
      _mint(params, state, zapInResult, fixedParams);
    } else {
      _mintAmounts(
        params, state, zapInResult, preview.liquidity, preview.addedAmount0, preview.addedAmount1
      );
    }
  }
}
