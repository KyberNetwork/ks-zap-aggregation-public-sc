// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IZapSolidlyV2Adapter} from '../../interfaces/adapters/solidly-v2/IZapSolidlyV2Adapter.sol';
import {IZapSolidlyV2Helper} from '../../interfaces/adapters/solidly-v2/IZapSolidlyV2Helper.sol';

import {CallbackDispatcher} from '../../base/CallbackDispatcher.sol';
import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapHelperCaller} from '../../base/ZapHelperCaller.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {LiquidityAction} from '../../types/LiquidityAction.sol';
import {PackedU128} from '../../types/PackedU128.sol';
import {ISolidlyV2Pair} from '../../vendors/solidly-v2/ISolidlyV2Pair.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/**
 * @title ZapSolidlyV2Adapter
 * @notice Adds liquidity to a Solidly V2 pair with the token balances of the account that
 * delegatecalls it, or removes liquidity tokens that account holds
 * @dev AHV2ProxyCallee delegatecalls the adapter, so the balances are those of the proxy. The
 * adapter serves every Solidly V2 fork through the helper of that fork.
 */
contract ZapSolidlyV2Adapter is
  IZapSolidlyV2Adapter,
  ImmutableState,
  ZapHelperCaller,
  CallbackDispatcher
{
  using TokenHelper for address;
  using CommonLibrary for *;

  /// @dev Tokens of the pair and amounts to add of a zap in
  struct ZapInState {
    address token0;
    address token1;
    uint256 amount0;
    uint256 amount1;
  }

  /// @param _WETH The wrapped native token
  constructor(address _WETH) ImmutableState(_WETH) {}

  /// @dev Accepts native balance
  receive() external payable {}

  /**
   * @notice Delegatecalls a callback to the target registered for its selector
   * @param data The calldata
   * @return The return data of the target
   */
  fallback(bytes calldata data) external returns (bytes memory) {
    return _fallback(data);
  }

  /**
   * @inheritdoc IAHV2Callee
   * @dev `ownerData` is `abi.encodePacked(LiquidityAction action, bytes actionParams)`: the
   * first byte is the action and the remaining bytes are the action parameters. For
   * `ADD_LIQUIDITY`, `actionParams` is `abi.encode(ZapInOwnerParams)` and `solverData` is the
   * required `abi.encode(ZapInSolverParams)`. For `REMOVE_LIQUIDITY`, `actionParams` is
   * `abi.encode(RemoveOwnerParams)` and `solverData` is either empty, which sets the minimum
   * amounts to zero, or `abi.encode(RemoveSolverParams)`. An invalid action byte reverts with the
   * panic code 0x21.
   */
  function execute(bytes calldata ownerData, bytes calldata solverData)
    external
    payable
    returns (bytes memory)
  {
    LiquidityAction action = LiquidityAction(uint8(ownerData[0]));
    bytes calldata actionParams = ownerData[1:];

    if (action == LiquidityAction.ADD_LIQUIDITY) {
      return _zapIn(actionParams, solverData);
    }
    return _remove(actionParams, solverData);
  }

  /// @dev Adds liquidity as described by `data` and `solverData` in up to two passes
  function _zapIn(bytes calldata data, bytes calldata solverData) internal returns (bytes memory) {
    ZapInOwnerParams calldata params;
    assembly ('memory-safe') {
      params := data.offset
    }

    ZapInSolverParams calldata solverParams;
    assembly ('memory-safe') {
      solverParams := solverData.offset
    }

    ZapInState memory state;
    state.token0 = ISolidlyV2Pair(params.pool).token0();
    state.token1 = ISolidlyV2Pair(params.pool).token1();

    if (state.token0 == address(WETH) || state.token1 == address(WETH)) {
      WETH.wrapETH();
    }

    ZapInResult memory zapInResult;
    zapInResult.pool = params.pool;
    zapInResult.recipient = params.recipient;
    zapInResult.originalAmount0 = state.token0.selfBalanceMinusOne();
    zapInResult.originalAmount1 = state.token1.selfBalanceMinusOne();

    // Both passes call `poolSwap` of the helper of the solver with the same solver parameters.
    // First pass: the helper receives the token balances less 1 wei. It swaps unless `skipSwap` is
    // set and returns the amounts to add at the reserves. The pass adds the amounts and the
    // liquidity that the helper returns, and reverts when that liquidity is zero.
    uint256 liquidityToAdd = _poolSwap(
      data,
      solverData,
      solverParams.helper,
      state,
      IZapSolidlyV2Helper.PoolSwapAdditionalParams({
        amount0: zapInResult.originalAmount0, amount1: zapInResult.originalAmount1
      })
    );

    require(liquidityToAdd != 0, ZapInSolidlyV2InsufficientLiquidity());
    _mint(params, state, zapInResult);

    // Second pass: runs when `skipSwap` is not set and the leftover of token0 or token1 is at
    // least its value in `minZapInAmounts`. The helper receives the leftover balances less 1 wei,
    // and the addition is skipped when the liquidity to add is zero. The leftover balances stay in
    // the proxy.
    if (!solverParams.skipSwap && _reachesMinimums(state, solverParams.minZapInAmounts)) {
      liquidityToAdd = _poolSwap(
        data,
        solverData,
        solverParams.helper,
        state,
        IZapSolidlyV2Helper.PoolSwapAdditionalParams({
          amount0: state.token0.selfBalanceMinusOne(), amount1: state.token1.selfBalanceMinusOne()
        })
      );
      if (liquidityToAdd != 0) {
        _mint(params, state, zapInResult);
      }
    }

    // `minLiquidity` is checked on the liquidity added by both passes.
    require(
      zapInResult.addedLiquidity >= params.minLiquidity, ZapInSolidlyV2InsufficientLiquidity()
    );

    // The leftover balances of token0 and token1, minus 1, are recorded after the last addition.
    zapInResult.remainingAmount0 = state.token0.selfBalanceMinusOne();
    zapInResult.remainingAmount1 = state.token1.selfBalanceMinusOne();

    bytes memory result = abi.encode(zapInResult);
    emit ZapIn(result);

    return result;
  }

  /// @dev Returns whether the balance of token0 or token1, minus 1, is at least its minimum in
  /// `minZapInAmounts`
  function _reachesMinimums(ZapInState memory state, PackedU128 minZapInAmounts)
    internal
    view
    returns (bool)
  {
    return state.token0.selfBalanceMinusOne() >= minZapInAmounts.value0()
      || state.token1.selfBalanceMinusOne() >= minZapInAmounts.value1();
  }

  /// @dev Calls `helper` with the amounts in `additionalParams`, records the amounts to add that
  /// it returns in `state` and returns the liquidity they add
  function _poolSwap(
    bytes calldata ownerData,
    bytes calldata solverData,
    address helper,
    ZapInState memory state,
    IZapSolidlyV2Helper.PoolSwapAdditionalParams memory additionalParams
  ) internal returns (uint256 liquidityToAdd) {
    bytes memory additionalData = abi.encode(additionalParams);

    bytes memory returnData = _poolSwap(helper, ownerData, solverData, additionalData);
    IZapSolidlyV2Helper.PoolSwapResult memory result =
      abi.decode(abi.decode(returnData, (bytes)), (IZapSolidlyV2Helper.PoolSwapResult));

    state.amount0 = result.amount0ToAdd;
    state.amount1 = result.amount1ToAdd;
    return result.liquidityToAdd;
  }

  /// @dev Transfers the amounts to add in `state` to the pair, mints to the recipient and records
  /// the addition in `zapInResult`
  function _mint(
    ZapInOwnerParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    state.token0.safeTransfer(params.pool, state.amount0);
    state.token1.safeTransfer(params.pool, state.amount1);
    uint256 liquidity = ISolidlyV2Pair(params.pool).mint(params.recipient);

    unchecked {
      zapInResult.addedLiquidity += liquidity;
      zapInResult.addedAmount0 += state.amount0;
      zapInResult.addedAmount1 += state.amount1;
    }
  }

  /// @dev Burns the liquidity tokens described by `data` into the proxy and checks the received
  /// amounts against the minimums of `solverData`
  function _remove(bytes calldata data, bytes calldata solverData) internal returns (bytes memory) {
    RemoveOwnerParams calldata params;
    assembly ('memory-safe') {
      params := data.offset
    }

    PackedU128 minRemoveAmounts = PackedU128.wrap(0);
    if (solverData.length != 0) {
      RemoveSolverParams calldata solverParams;
      assembly ('memory-safe') {
        solverParams := solverData.offset
      }
      minRemoveAmounts = solverParams.minRemoveAmounts;
    }

    address token0 = ISolidlyV2Pair(params.pool).token0();
    address token1 = ISolidlyV2Pair(params.pool).token1();
    uint256 balance0Before = token0.selfBalance();
    uint256 balance1Before = token1.selfBalance();

    // The pair burns the liquidity tokens it holds and transfers the tokens to the proxy. The
    // amounts are the balance increases, which exclude a fee on transfer.
    params.pool.safeTransfer(params.pool, params.liquidity);
    ISolidlyV2Pair(params.pool).burn(address(this));

    uint256 amount0 = token0.selfBalance() - balance0Before;
    uint256 amount1 = token1.selfBalance() - balance1Before;

    // The pair has no minimum amounts, so the adapter checks them.
    require(
      amount0 >= minRemoveAmounts.value0() && amount1 >= minRemoveAmounts.value1(),
      RemoveSolidlyV2InsufficientAmounts()
    );

    RemoveResult memory removeResult = RemoveResult({
      pool: params.pool, liquidity: params.liquidity, amount0: amount0, amount1: amount1
    });
    bytes memory result = abi.encode(removeResult);
    emit RemoveLiquidity(result);

    return result;
  }
}
