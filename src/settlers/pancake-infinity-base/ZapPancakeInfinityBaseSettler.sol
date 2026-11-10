// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IKSZapExecutor} from '../../interfaces/IKSZapExecutor.sol';
import {
  IZapPancakeInfinityBaseSettler
} from '../../interfaces/settlers/pancake-infinity-base/IZapPancakeInfinityBaseSettler.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapAgainHelperCaller} from '../../base/ZapAgainHelperCaller.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';

import {Actions} from '../../vendors/pancake-infinity/Actions.sol';
import {ICLPoolManager} from '../../vendors/pancake-infinity/ICLPoolManager.sol';
import {ICLPositionManager} from '../../vendors/pancake-infinity/ICLPositionManager.sol';
import {IVault} from '../../vendors/pancake-infinity/IVault.sol';

import {LiquidityAmounts} from '../../vendors/uniswap-v4/LiquidityAmounts.sol';
import {SqrtPriceMath} from '../../vendors/uniswap-v4/SqrtPriceMath.sol';
import {TickMath} from '../../vendors/uniswap-v4/TickMath.sol';

import {IAllowanceTransfer} from 'ks-common-sc/src/interfaces/IAllowanceTransfer.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';

/// @title ZapPancakeInfinityBaseSettler
/// @notice Adds liquidity to a Pancake Infinity CL position with the token balances this contract
/// holds, when KSZapRouterV3 delegatecalls it in an owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained. A new
/// position is minted to this contract and transferred to the recipient after the lock.
contract ZapPancakeInfinityBaseSettler is
  IZapPancakeInfinityBaseSettler,
  ImmutableState,
  ZapAgainHelperCaller
{
  using TokenHelper for address;
  using CommonLibrary for *;

  /// @dev Pool, price bounds and amounts of a zap in
  struct ZapInState {
    IVault vault;
    ICLPoolManager clPoolManager;
    bytes32 poolId;
    uint160 sqrtPriceLowerX96;
    uint160 sqrtPriceUpperX96;
    uint256 tokenId;
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
      params := add(data.offset, calldataload(data.offset))
    }

    if (params.poolKey.currency0.isNative()) {
      WETH.unwrapWETH();
    } else if (
      params.poolKey.currency0 == address(WETH) || params.poolKey.currency1 == address(WETH)
    ) {
      WETH.wrapETH();
    }

    if (params.approvalFlags.at(0) || params.approvalFlags.at(1)) {
      IAllowanceTransfer permit2 = ICLPositionManager(params.posManager).permit2();
      if (params.approvalFlags.at(0)) {
        CommonLibrary.permit2ApproveInf(params.poolKey.currency0, params.posManager, permit2);
      }
      if (params.approvalFlags.at(1)) {
        CommonLibrary.permit2ApproveInf(params.poolKey.currency1, params.posManager, permit2);
      }
    }

    bytes memory returnData = IVault(params.vault).lock(data);

    ZapInResult memory zapInResult = abi.decode(returnData, (ZapInResult));

    if (
      zapInResult.tokenId != 0
        && (params.tokenId == 0
          || IERC721(params.posManager).ownerOf(zapInResult.tokenId) != params.recipient)
    ) {
      IERC721(params.posManager).transferFrom(address(this), params.recipient, zapInResult.tokenId);
    }

    zapInResult.remainingAmount0 = params.poolKey.currency0.selfBalanceMinusOne();
    if (zapInResult.remainingAmount0 > 0) {
      params.poolKey.currency0.safeTransfer(params.refundRecipient, zapInResult.remainingAmount0);
    }

    zapInResult.remainingAmount1 = params.poolKey.currency1.selfBalanceMinusOne();
    if (zapInResult.remainingAmount1 > 0) {
      params.poolKey.currency1.safeTransfer(params.refundRecipient, zapInResult.remainingAmount1);
    }

    bytes memory result = abi.encode(zapInResult);
    emit ZapIn(result);

    return result;
  }

  /// @inheritdoc IZapPancakeInfinityBaseSettler
  function lockAcquired(bytes calldata data) external returns (bytes memory) {
    ZapInParams calldata params;
    assembly ('memory-safe') {
      params := add(data.offset, calldataload(data.offset))
    }

    ZapInState memory state;
    state.vault = IVault(msg.sender);
    state.clPoolManager = ICLPoolManager(params.poolKey.poolManager);
    state.poolId = params.poolKey.toId();
    state.sqrtPriceLowerX96 = TickMath.getSqrtPriceAtTick(params.tickLower);
    state.sqrtPriceUpperX96 = TickMath.getSqrtPriceAtTick(params.tickUpper);
    state.tokenId = params.tokenId;
    state.amount0 = params.poolKey.currency0.selfBalanceMinusOne();
    state.amount1 = params.poolKey.currency1.selfBalanceMinusOne();

    ZapInResult memory zapInResult;
    zapInResult.posManager = params.posManager;
    zapInResult.recipient = params.recipient;
    zapInResult.originalAmount0 = state.amount0;
    zapInResult.originalAmount1 = state.amount1;

    _addLiquidity(params, state, zapInResult);

    if (
      params.zapAgain.helper != address(0)
        && (state.amount0 >= params.zapAgain.minZapInAmounts.value0()
          || state.amount1 >= params.zapAgain.minZapInAmounts.value1())
    ) {
      _zapAgain(params, state, zapInResult);
    }

    require(
      zapInResult.positionLiquidity >= params.minLiquidity,
      ZapInPancakeInfinityInsufficientLiquidity()
    );

    zapInResult.tokenId = state.tokenId;

    return abi.encode(zapInResult);
  }

  /// @dev Adds the amounts in `state` to the position and records the addition in `zapInResult`
  function _addLiquidity(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    (uint128 liquidity, uint256 addedAmount0, uint256 addedAmount1) = _previewAddLiquidity(state);
    if (liquidity == 0) {
      return;
    }

    bool currency0Native = params.poolKey.currency0.isNative();
    uint128 liquidityBefore = 0;

    if (params.readBalanceFlag) {
      if (addedAmount0 > state.amount0) {
        addedAmount0 = state.amount0;
      }
      if (addedAmount1 > state.amount1) {
        addedAmount1 = state.amount1;
      }

      /// Settles the added amounts for the position manager, which computes the liquidity from
      /// the credited deltas
      _settleFor(state.vault, params.poolKey.currency0, params.posManager, addedAmount0);
      _settleFor(state.vault, params.poolKey.currency1, params.posManager, addedAmount1);

      if (state.tokenId != 0) {
        liquidityBefore = ICLPositionManager(params.posManager).getPositionLiquidity(state.tokenId);
      }
    }

    bytes memory actions = new bytes(3);
    bytes[] memory actionParams = new bytes[](3);

    if (state.tokenId == 0) {
      state.tokenId = ICLPositionManager(params.posManager).nextTokenId();

      if (params.readBalanceFlag) {
        actions[0] = bytes1(uint8(Actions.CL_MINT_POSITION_FROM_DELTAS));
        actionParams[0] = abi.encode(
          params.poolKey,
          params.tickLower,
          params.tickUpper,
          type(uint128).max,
          type(uint128).max,
          address(this),
          params.addLiquidityHookData
        );
      } else {
        actions[0] = bytes1(uint8(Actions.CL_MINT_POSITION));
        actionParams[0] = abi.encode(
          params.poolKey,
          params.tickLower,
          params.tickUpper,
          liquidity,
          type(uint128).max,
          type(uint128).max,
          address(this),
          params.addLiquidityHookData
        );
      }
    } else {
      if (params.readBalanceFlag) {
        actions[0] = bytes1(uint8(Actions.CL_INCREASE_LIQUIDITY_FROM_DELTAS));
        actionParams[0] = abi.encode(
          state.tokenId, type(uint128).max, type(uint128).max, params.addLiquidityHookData
        );
      } else {
        actions[0] = bytes1(uint8(Actions.CL_INCREASE_LIQUIDITY));
        actionParams[0] = abi.encode(
          state.tokenId,
          liquidity,
          type(uint128).max,
          type(uint128).max,
          params.addLiquidityHookData
        );
      }
    }

    actions[1] = bytes1(uint8(Actions.CLOSE_CURRENCY));
    actionParams[1] = abi.encode(params.poolKey.currency0);

    actions[2] = bytes1(uint8(Actions.CLOSE_CURRENCY));
    actionParams[2] = abi.encode(params.poolKey.currency1);

    ICLPositionManager(params.posManager)
    .modifyLiquiditiesWithoutLock{
      value: currency0Native && !params.readBalanceFlag ? addedAmount0 : 0
    }(
      actions, actionParams
    );

    if (params.readBalanceFlag) {
      unchecked {
        liquidity = ICLPositionManager(params.posManager).getPositionLiquidity(state.tokenId)
          - liquidityBefore;
      }

      uint256 balance0 = params.poolKey.currency0.selfBalanceMinusOne();
      uint256 balance1 = params.poolKey.currency1.selfBalanceMinusOne();

      unchecked {
        addedAmount0 = state.amount0 > balance0 ? state.amount0 - balance0 : 0;
        addedAmount1 = state.amount1 > balance1 ? state.amount1 - balance1 : 0;
      }

      state.amount0 = balance0;
      state.amount1 = balance1;
    } else {
      unchecked {
        state.amount0 = state.amount0 > addedAmount0 ? state.amount0 - addedAmount0 : 0;
        state.amount1 = state.amount1 > addedAmount1 ? state.amount1 - addedAmount1 : 0;
      }
    }

    unchecked {
      zapInResult.positionLiquidity += liquidity;
      zapInResult.addedAmount0 += addedAmount0;
      zapInResult.addedAmount1 += addedAmount1;
    }
  }

  /// @dev Swaps the remaining amounts through the helper and adds them to the position
  function _zapAgain(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    bytes memory fixedParams = abi.encode(
      ZapInFixedParams({
        posManager: params.posManager,
        vault: params.vault,
        poolKey: params.poolKey,
        tickLower: params.tickLower,
        tickUpper: params.tickUpper,
        sqrtPriceLimit0X96: params.zapAgain.sqrtPriceLimit0X96,
        sqrtPriceLimit1X96: params.zapAgain.sqrtPriceLimit1X96,
        iterations: params.zapAgain.iterations,
        swapHookData: params.zapAgain.swapHookData,
        addLiquidityHookData: '',
        optimizer: address(0),
        optimizeFixedParams: '',
        readBalanceFlag: params.readBalanceFlag
      })
    );
    bytes memory variableParams = abi.encode(PoolSwapVariableParams({extraData: ''}));

    PoolSwapResult memory swapResult =
      abi.decode(_poolSwap(params.zapAgain.helper, fixedParams, variableParams), (PoolSwapResult));

    state.amount0 = swapResult.amount0;
    state.amount1 = swapResult.amount1;

    if (swapResult.positionLiquidity != 0) {
      _addLiquidity(params, state, zapInResult);
    }
  }

  /// @dev Pays `amount` of `currency` to the vault, crediting `recipient` with the amount that the
  /// vault actually received
  function _settleFor(IVault vault, address currency, address recipient, uint256 amount) internal {
    if (amount == 0) {
      return;
    }

    if (currency.isNative()) {
      vault.settleFor{value: amount}(recipient);
    } else {
      vault.sync(currency);
      currency.safeTransfer(address(vault), amount);
      vault.settleFor(recipient);
    }
  }

  /**
   * @dev Computes the liquidity that the amounts in `state` add to the price range at the current
   * pool price, and the amounts of currency0 and currency1, rounded up, that the liquidity requires
   * @param state The pool, the price range and the amounts to add
   * @return liquidity The liquidity added
   * @return addedAmount0 The amount of currency0 the liquidity requires
   * @return addedAmount1 The amount of currency1 the liquidity requires
   */
  function _previewAddLiquidity(ZapInState memory state)
    internal
    view
    returns (uint128 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    (uint160 sqrtPriceX96,,,) = state.clPoolManager.getSlot0(state.poolId);

    liquidity = uint128(
      LiquidityAmounts.getLiquidityForAmounts(
        sqrtPriceX96, state.sqrtPriceLowerX96, state.sqrtPriceUpperX96, state.amount0, state.amount1
      )
    );

    if (sqrtPriceX96 <= state.sqrtPriceLowerX96) {
      addedAmount0 = SqrtPriceMath.getAmount0Delta(
        state.sqrtPriceLowerX96, state.sqrtPriceUpperX96, liquidity, true
      );
    } else if (sqrtPriceX96 < state.sqrtPriceUpperX96) {
      addedAmount0 =
        SqrtPriceMath.getAmount0Delta(sqrtPriceX96, state.sqrtPriceUpperX96, liquidity, true);
      addedAmount1 =
        SqrtPriceMath.getAmount1Delta(state.sqrtPriceLowerX96, sqrtPriceX96, liquidity, true);
    } else {
      addedAmount1 = SqrtPriceMath.getAmount1Delta(
        state.sqrtPriceLowerX96, state.sqrtPriceUpperX96, liquidity, true
      );
    }
  }
}
