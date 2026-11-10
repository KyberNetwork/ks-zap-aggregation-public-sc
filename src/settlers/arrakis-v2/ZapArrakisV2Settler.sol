// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IKSZapExecutor} from '../../interfaces/IKSZapExecutor.sol';
import {IZapArrakisV2Settler} from '../../interfaces/settlers/arrakis-v2/IZapArrakisV2Settler.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapAgainHelperCaller} from '../../base/ZapAgainHelperCaller.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {IArrakisV2Router} from '../../vendors/arrakis-v2/IArrakisV2Router.sol';
import {IUniswapV3Pool} from '../../vendors/uniswap-v3/IUniswapV3Pool.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/// @title ZapArrakisV2Settler
/// @notice Deposits into an Arrakis V2 vault with the token balances this contract holds, when
/// KSZapRouterV3 delegatecalls it in an owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained. The
/// swap callbacks of the zap again are forwarded to the helper.
contract ZapArrakisV2Settler is IZapArrakisV2Settler, ImmutableState, ZapAgainHelperCaller {
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

    if (
      params.zapAgain.helper != address(0)
        && (state.amount0 >= params.zapAgain.minZapInAmounts.value0()
          || state.amount1 >= params.zapAgain.minZapInAmounts.value1())
    ) {
      _zapAgain(params, state, zapInResult);
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

  /// @dev Swaps the remaining amounts through the helper and deposits them into the vault
  function _zapAgain(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    bytes memory fixedParams = abi.encode(
      ZapInFixedParams({
        vault: params.vault,
        pool: params.pool,
        router: params.router,
        gauge: params.gauge,
        sqrtPriceLimit0X96: params.zapAgain.sqrtPriceLimit0X96,
        sqrtPriceLimit1X96: params.zapAgain.sqrtPriceLimit1X96,
        iterations: params.zapAgain.iterations
      })
    );
    bytes memory variableParams = abi.encode(PoolSwapVariableParams({offchainData: ''}));

    PoolSwapResult memory swapResult =
      abi.decode(_poolSwap(params.zapAgain.helper, fixedParams, variableParams), (PoolSwapResult));

    state.amount0 = swapResult.amount0;
    state.amount1 = swapResult.amount1;

    if (swapResult.shares != 0) {
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
