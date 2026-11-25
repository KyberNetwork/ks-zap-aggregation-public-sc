// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IKSZapExecutor} from '../../interfaces/IKSZapExecutor.sol';
import {IZapPoolSwapAgainHelper} from '../../interfaces/adapters/IZapPoolSwapAgainHelper.sol';
import {IZapArrakisV2Adapter} from '../../interfaces/adapters/arrakis-v2/IZapArrakisV2Adapter.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapHelperCaller} from '../../base/ZapHelperCaller.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {ZapAgainRecord} from '../../libraries/ZapAgainRecord.sol';
import {IArrakisV2Router} from '../../vendors/arrakis-v2/IArrakisV2Router.sol';
import {IUniswapV3Pool} from '../../vendors/uniswap-v3/IUniswapV3Pool.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/// @title ZapArrakisV2Adapter
/// @notice Deposits into an Arrakis V2 vault with the token balances this contract holds, when
/// KSZapRouterV3 delegatecalls it in an owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained. The
/// swap callbacks of the zap again are forwarded to the helper.
contract ZapArrakisV2Adapter is IZapArrakisV2Adapter, ImmutableState, ZapHelperCaller {
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

  /// @dev Forwards the swap callbacks of the pool swap of the zap again to the helper
  fallback() external {
    _forwardUniswapV3SwapCallback();
  }

  /// @inheritdoc IKSZapExecutor
  function executeZap(bytes calldata data) external payable returns (bytes memory) {
    return _executeZap(data);
  }

  /**
   * @inheritdoc IAHV2Callee
   * @dev `solverData` is ignored
   */
  function execute(bytes calldata ownerData, bytes calldata)
    external
    payable
    returns (bytes memory)
  {
    return _executeZap(ownerData);
  }

  /// @dev Adds liquidity as described by `data`
  function _executeZap(bytes calldata data) internal returns (bytes memory) {
    bytes memory zapAgainParams = ZapAgainRecord.load();

    ZapInParams calldata params;
    assembly ('memory-safe') {
      params := data.offset
    }

    ZapInState memory state;
    state.token0 = IUniswapV3Pool(params.pool).token0();
    state.token1 = IUniswapV3Pool(params.pool).token1();

    if (state.token0 == address(WETH) || state.token1 == address(WETH)) {
      WETH.wrapETH();
    }

    state.amount0 = state.token0.selfBalanceMinusOne();
    state.amount1 = state.token1.selfBalanceMinusOne();

    ZapInResult memory zapInResult;
    zapInResult.vault = params.vault;
    zapInResult.recipient = params.recipient;
    zapInResult.originalAmount0 = state.amount0;
    zapInResult.originalAmount1 = state.amount1;

    if (params.approvalFlags.at(0)) {
      state.token0.forceApproveInf(_approveTarget(params));
    }
    if (params.approvalFlags.at(1)) {
      state.token1.forceApproveInf(_approveTarget(params));
    }

    _addLiquidity(params, state, zapInResult);

    if (zapAgainParams.length != 0 && params.helper != address(0)) {
      _zapAgain(params, state, zapInResult, zapAgainParams);
    }

    require(zapInResult.shares >= params.minShares, ZapArrakisV2InsufficientShares());

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

  /// @dev Deposits the amounts in `state` into the vault and records the deposit in `zapInResult`
  function _addLiquidity(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    (uint256 shares, uint256 addedAmount0, uint256 addedAmount1) = _deposit(params, state);

    unchecked {
      state.amount0 -= addedAmount0;
      state.amount1 -= addedAmount1;
      zapInResult.shares += shares;
      zapInResult.addedAmount0 += addedAmount0;
      zapInResult.addedAmount1 += addedAmount1;
    }
  }

  /// @dev Swaps the remaining amounts through the helper with the recorded parameters and deposits
  /// them into the vault
  function _zapAgain(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult,
    bytes memory zapAgainParams
  ) internal {
    ArrakisV2ZapAgainParams memory zapAgain = abi.decode(zapAgainParams, (ArrakisV2ZapAgainParams));

    bytes memory fixedParams = abi.encode(
      ZapInFixedParams({
        vault: params.vault,
        pool: params.pool,
        router: params.router,
        gauge: params.gauge,
        sqrtPriceLimit0X96: zapAgain.sqrtPriceLimit0X96,
        sqrtPriceLimit1X96: zapAgain.sqrtPriceLimit1X96,
        iterations: zapAgain.iterations
      })
    );

    IZapPoolSwapAgainHelper.PoolSwapAgainResult memory result =
      _poolSwapAgain(params.helper, fixedParams, zapAgain.minZapInAmounts);

    state.amount0 = result.amount0;
    state.amount1 = result.amount1;

    if (result.liquidity != 0) {
      _addLiquidity(params, state, zapInResult);
    }
  }

  /// @dev Deposits the given amounts into the vault, minting the shares to the recipient
  function _deposit(ZapInParams calldata params, ZapInState memory state)
    internal
    virtual
    returns (uint256 shares, uint256 addedAmount0, uint256 addedAmount1)
  {
    (addedAmount0, addedAmount1, shares) = IArrakisV2Router(params.router)
      .addLiquidity(
        IArrakisV2Router.AddLiquidityData({
          amount0Max: state.amount0,
          amount1Max: state.amount1,
          amount0Min: 0,
          amount1Min: 0,
          amountSharesMin: 0,
          vault: params.vault,
          receiver: params.recipient,
          gauge: params.gauge
        })
      );
  }

  /// @dev Returns the contract approved to pull the tokens of the deposit
  function _approveTarget(ZapInParams calldata params) internal pure virtual returns (address) {
    return params.router;
  }
}
