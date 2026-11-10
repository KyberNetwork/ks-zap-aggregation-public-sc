// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IKSZapExecutor} from '../../interfaces/IKSZapExecutor.sol';
import {IZapSolidlyV2Settler} from '../../interfaces/settlers/solidly-v2/IZapSolidlyV2Settler.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapAgainHelperCaller} from '../../base/ZapAgainHelperCaller.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {ISolidlyV2Pair} from '../../vendors/solidly-v2/ISolidlyV2Pair.sol';

import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/// @title ZapSolidlyV2Settler
/// @notice Adds liquidity to a Solidly V2 pair with the token balances this contract holds, when
/// KSZapRouterV3 delegatecalls it in an owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained. The
/// contract serves every Solidly V2 fork through the helper of that fork.
contract ZapSolidlyV2Settler is IZapSolidlyV2Settler, ImmutableState, ZapAgainHelperCaller {
  using TokenHelper for address;
  using Math for uint256;
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

    _mint(params, state, zapInResult);

    if (
      params.helper != address(0)
        && (state.amount0 >= params.minZapInAmounts.value0()
          || state.amount1 >= params.minZapInAmounts.value1())
    ) {
      _zapAgain(params, state, zapInResult);
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

  /// @dev Mints liquidity to the recipient with the amounts in `state` and records the mint in
  /// `zapInResult`
  function _mint(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    (uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1) = _previewMint(params, state);

    if (liquidity == 0) {
      return;
    }

    state.token0.safeTransfer(params.pool, addedAmount0);
    state.token1.safeTransfer(params.pool, addedAmount1);
    ISolidlyV2Pair(params.pool).mint(params.recipient);

    unchecked {
      if (params.readBalanceFlag) {
        state.amount0 = state.token0.selfBalanceMinusOne();
        state.amount1 = state.token1.selfBalanceMinusOne();
      } else {
        state.amount0 -= addedAmount0;
        state.amount1 -= addedAmount1;
      }

      zapInResult.liquidity += liquidity;
      zapInResult.addedAmount0 += addedAmount0;
      zapInResult.addedAmount1 += addedAmount1;
    }
  }

  /// @dev Computes the liquidity minted by the amounts in `state` and the amounts of each token it
  /// consumes, using the reserves and the total supply of the pair
  function _previewMint(ZapInParams calldata params, ZapInState memory state)
    internal
    view
    returns (uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    (uint256 reserve0, uint256 reserve1,) = ISolidlyV2Pair(params.pool).getReserves();
    uint256 totalSupply = ISolidlyV2Pair(params.pool).totalSupply();

    liquidity =
      Math.min(state.amount0 * totalSupply / reserve0, state.amount1 * totalSupply / reserve1);

    addedAmount0 = (liquidity * reserve0).ceilDiv(totalSupply);
    addedAmount1 = (liquidity * reserve1).ceilDiv(totalSupply);
  }

  /// @dev Swaps the remaining amounts through the helper and mints them into the pair
  function _zapAgain(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    bytes memory fixedParams = abi.encode(
      ZapInFixedParams({pool: params.pool, readBalanceFlag: params.readBalanceFlag})
    );

    PoolSwapResult memory swapResult =
      abi.decode(_poolSwap(params.helper, fixedParams, ''), (PoolSwapResult));

    state.amount0 = swapResult.amount0;
    state.amount1 = swapResult.amount1;

    _mint(params, state, zapInResult);
  }
}
