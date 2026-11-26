// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapALMVaultAdapter} from '../../interfaces/adapters/alm-vault/IZapALMVaultAdapter.sol';
import {IZapALMVaultHelper} from '../../interfaces/adapters/alm-vault/IZapALMVaultHelper.sol';

import {CallbackDispatcher} from '../../base/CallbackDispatcher.sol';
import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapHelperCaller} from '../../base/ZapHelperCaller.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {LiquidityAction} from '../../types/LiquidityAction.sol';
import {PackedU128} from '../../types/PackedU128.sol';
import {IUniswapV3Pool} from '../../vendors/uniswap-v3/IUniswapV3Pool.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/**
 * @title ZapALMVaultAdapter
 * @notice Deposits the token balances of the account that delegatecalls it into a vault of
 * concentrated liquidity positions, or removes vault shares that account holds
 * @dev AHV2ProxyCallee delegatecalls the adapter, so the balances and the shares are those of the
 * proxy. The callbacks of the pools are delegatecalled to the targets that the helper registers.
 * A vault protocol implements the deposit, the approval target and the withdrawal.
 */
abstract contract ZapALMVaultAdapter is
  IZapALMVaultAdapter,
  ImmutableState,
  ZapHelperCaller,
  CallbackDispatcher
{
  using TokenHelper for address;
  using CommonLibrary for *;

  /// @dev Tokens and amounts to deposit of a zap in
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

  /// @dev Deposits as described by `data` and `solverData` in up to two passes
  function _zapIn(bytes calldata data, bytes calldata solverData) internal returns (bytes memory) {
    ZapInOwnerParams calldata params;
    assembly ('memory-safe') {
      params := data.offset
    }

    ZapInSolverParams calldata solverParams;
    assembly ('memory-safe') {
      solverParams := add(solverData.offset, calldataload(solverData.offset))
    }

    ZapInState memory state;
    state.token0 = IUniswapV3Pool(params.pool).token0();
    state.token1 = IUniswapV3Pool(params.pool).token1();

    if (state.token0 == address(WETH) || state.token1 == address(WETH)) {
      WETH.wrapETH();
    }

    ZapInResult memory zapInResult;
    zapInResult.vault = params.vault;
    zapInResult.recipient = params.recipient;
    zapInResult.originalAmount0 = state.token0.selfBalanceMinusOne();
    zapInResult.originalAmount1 = state.token1.selfBalanceMinusOne();

    // Both passes call `poolSwap` of the helper of the solver with the same `poolSwap`
    // parameters.
    // First pass: the helper receives the token balances less 1 wei and the extra data. It swaps
    // when `poolSwap.iterations` is not zero and otherwise returns the amounts unchanged. The pass
    // deposits the amounts that the helper returns, and reverts when the shares that it returns
    // are zero.
    uint256 sharesToAdd = _poolSwap(
      data,
      solverData,
      solverParams.helper,
      state,
      IZapALMVaultHelper.PoolSwapAdditionalParams({
        amount0: zapInResult.originalAmount0,
        amount1: zapInResult.originalAmount1,
        useExtraData: true
      })
    );

    require(sharesToAdd != 0, ZapInVaultInsufficientShares());

    address approveTarget = _approveTarget(params);
    if (solverParams.approvalFlags.at(0)) {
      state.token0.forceApproveInf(approveTarget);
    }
    if (solverParams.approvalFlags.at(1)) {
      state.token1.forceApproveInf(approveTarget);
    }
    _addLiquidity(params, state, zapInResult);

    // Second pass: runs when `poolSwap.iterations` is not zero and the leftover of token0 or
    // token1 is at least its value in `minZapInAmounts`. The helper receives the leftover balances
    // less 1 wei without the extra data, and the deposit is skipped when the shares to add are
    // zero. The leftover balances stay in the proxy.
    if (
      solverParams.poolSwap.iterations != 0 && _reachesMinimums(state, solverParams.minZapInAmounts)
    ) {
      sharesToAdd = _poolSwap(
        data,
        solverData,
        solverParams.helper,
        state,
        IZapALMVaultHelper.PoolSwapAdditionalParams({
          amount0: state.token0.selfBalanceMinusOne(),
          amount1: state.token1.selfBalanceMinusOne(),
          useExtraData: false
        })
      );
      if (sharesToAdd != 0) {
        _addLiquidity(params, state, zapInResult);
      }
    }

    // `minShares` is checked on the shares minted by both passes.
    require(zapInResult.addedShares >= params.minShares, ZapInVaultInsufficientShares());

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

  /// @dev Calls `helper` with the amounts in `additionalParams`, records the balances after the
  /// swap that it returns in `state` and returns the shares they mint
  function _poolSwap(
    bytes calldata ownerData,
    bytes calldata solverData,
    address helper,
    ZapInState memory state,
    IZapALMVaultHelper.PoolSwapAdditionalParams memory additionalParams
  ) internal returns (uint256 sharesToAdd) {
    bytes memory additionalData = abi.encode(additionalParams);

    bytes memory returnData = _poolSwap(helper, ownerData, solverData, additionalData);
    IZapALMVaultHelper.PoolSwapResult memory result =
      abi.decode(abi.decode(returnData, (bytes)), (IZapALMVaultHelper.PoolSwapResult));

    state.amount0 = result.amount0AfterSwap;
    state.amount1 = result.amount1AfterSwap;
    return result.sharesToAdd;
  }

  /// @dev Deposits the amounts in `state`, deducts the deposited amounts from `state` and records
  /// the deposit in `zapInResult`
  function _addLiquidity(
    ZapInOwnerParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    (uint256 shares, uint256 addedAmount0, uint256 addedAmount1) = _deposit(params, state);

    unchecked {
      state.amount0 -= addedAmount0;
      state.amount1 -= addedAmount1;
      zapInResult.addedShares += shares;
      zapInResult.addedAmount0 += addedAmount0;
      zapInResult.addedAmount1 += addedAmount1;
    }
  }

  /// @dev Removes the shares described by `data` into the proxy and checks the received amounts
  /// against the minimums of `solverData`
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

    address token0 = IUniswapV3Pool(params.pool).token0();
    address token1 = IUniswapV3Pool(params.pool).token1();
    uint256 balance0Before = token0.selfBalance();
    uint256 balance1Before = token1.selfBalance();

    _withdraw(params);

    // The amounts are the balance increases of the proxy. The minimums are checked here because
    // the withdrawals run with zero minimums.
    uint256 amount0 = token0.selfBalance() - balance0Before;
    uint256 amount1 = token1.selfBalance() - balance1Before;
    require(
      amount0 >= minRemoveAmounts.value0() && amount1 >= minRemoveAmounts.value1(),
      RemoveVaultInsufficientAmounts()
    );

    RemoveResult memory removeResult = RemoveResult({
      vault: params.vault, shares: params.shares, amount0: amount0, amount1: amount1
    });
    bytes memory result = abi.encode(removeResult);
    emit RemoveLiquidity(result);

    return result;
  }

  /// @dev Deposits the amounts in `state` into the vault for the recipient and returns the shares
  /// minted and the amounts deposited
  function _deposit(ZapInOwnerParams calldata params, ZapInState memory state)
    internal
    virtual
    returns (uint256 shares, uint256 addedAmount0, uint256 addedAmount1);

  /// @dev Returns the contract that the approval flags approve to pull the tokens of the deposit
  function _approveTarget(ZapInOwnerParams calldata params) internal pure virtual returns (address);

  /// @dev Burns the shares of the proxy described by `params` and transfers the tokens to the proxy
  function _withdraw(RemoveOwnerParams calldata params) internal virtual;
}
