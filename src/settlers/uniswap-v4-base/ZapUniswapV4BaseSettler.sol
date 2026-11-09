// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IZapPreviewHelper} from '../../interfaces/settlers/IZapPreviewHelper.sol';
import {IZapSettler} from '../../interfaces/settlers/IZapSettler.sol';
import {
  IZapUniswapV4BaseSettler
} from '../../interfaces/settlers/uniswap-v4-base/IZapUniswapV4BaseSettler.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {Actions} from '../../vendors/uniswap-v4/Actions.sol';
import {BalanceDelta} from '../../vendors/uniswap-v4/BalanceDelta.sol';
import {CurrencySettler} from '../../vendors/uniswap-v4/CurrencySettler.sol';
import {IPoolManager} from '../../vendors/uniswap-v4/IPoolManager.sol';
import {IPositionManager} from '../../vendors/uniswap-v4/IPositionManager.sol';
import {LiquidityAmounts} from '../../vendors/uniswap-v4/LiquidityAmounts.sol';
import {SwapParams} from '../../vendors/uniswap-v4/PoolOperation.sol';
import {SqrtPriceMath} from '../../vendors/uniswap-v4/SqrtPriceMath.sol';
import {StateLibrary} from '../../vendors/uniswap-v4/StateLibrary.sol';
import {TickMath} from '../../vendors/uniswap-v4/TickMath.sol';
import {TransientStateLibrary} from '../../vendors/uniswap-v4/TransientStateLibrary.sol';

import {IAllowanceTransfer} from 'ks-common-sc/src/interfaces/IAllowanceTransfer.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';
import {
  ReentrancyGuardTransient
} from 'openzeppelin-contracts/contracts/utils/ReentrancyGuardTransient.sol';
import {TransientSlot} from 'openzeppelin-contracts/contracts/utils/TransientSlot.sol';

/// @title ZapUniswapV4BaseSettler
/// @notice Adds liquidity to a Uniswap V4 position with the token balances this contract holds, in
/// an owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained. A new
/// position is minted to this contract and transferred to the recipient after the unlock. The
/// unlock callback is accepted only from the pool manager of the ongoing zap in.
contract ZapUniswapV4BaseSettler is
  IZapUniswapV4BaseSettler,
  ImmutableState,
  ReentrancyGuardTransient
{
  using TokenHelper for address;
  using CommonLibrary for *;
  using TransientSlot for *;
  using StateLibrary for IPoolManager;
  using TransientStateLibrary for IPoolManager;
  using CurrencySettler for address;

  /// @dev Transient slot holding the pool manager of the ongoing zap in
  bytes32 private constant POOL_MANAGER_SLOT =
    bytes32(uint256(keccak256('ks.zap.settler.uniswap-v4-base.pool-manager')) - 1);

  /// @dev Pool, price bounds, position and amounts of a zap in
  struct ZapInState {
    IPoolManager poolManager;
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

  /// @inheritdoc IZapSettler
  function ksExecute(bytes calldata data) external payable nonReentrant returns (bytes memory) {
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
      IAllowanceTransfer permit2 = IPositionManager(params.posManager).permit2();

      if (params.approvalFlags.at(0)) {
        CommonLibrary.permit2ApproveInf(params.poolKey.currency0, params.posManager, permit2);
      }
      if (params.approvalFlags.at(1)) {
        CommonLibrary.permit2ApproveInf(params.poolKey.currency1, params.posManager, permit2);
      }
    }

    POOL_MANAGER_SLOT.asAddress().tstore(params.poolManager);
    bytes memory ret = IPoolManager(params.poolManager).unlock(data);
    POOL_MANAGER_SLOT.asAddress().tstore(address(0));

    ZapInResult memory zapInResult = abi.decode(ret, (ZapInResult));

    require(
      zapInResult.positionLiquidity >= params.minLiquidity, ZapInUniswapV4InsufficientLiquidity()
    );

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

  /// @inheritdoc IZapUniswapV4BaseSettler
  function unlockCallback(bytes calldata data) external returns (bytes memory) {
    require(
      msg.sender == POOL_MANAGER_SLOT.asAddress().tload(), InvalidUnlockCallbackCaller(msg.sender)
    );

    ZapInParams calldata params;
    assembly ('memory-safe') {
      params := add(data.offset, calldataload(data.offset))
    }

    ZapInState memory state;
    state.poolManager = IPoolManager(msg.sender);
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

    zapInResult.tokenId = state.tokenId;

    return abi.encode(zapInResult);
  }

  /// @dev Adds the amounts in `state` to the position and records the addition in `zapInResult`
  function _addLiquidity(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    (uint160 sqrtPriceX96,,,) = state.poolManager.getSlot0(state.poolId);

    uint128 liquidity = uint128(
      LiquidityAmounts.getLiquidityForAmounts(
        sqrtPriceX96, state.sqrtPriceLowerX96, state.sqrtPriceUpperX96, state.amount0, state.amount1
      )
    );
    if (liquidity == 0) {
      return;
    }

    (uint256 addedAmount0, uint256 addedAmount1) = _getAmountsForLiquidity(
      sqrtPriceX96, state.sqrtPriceLowerX96, state.sqrtPriceUpperX96, liquidity
    );

    bool currency0Native = params.poolKey.currency0.isNative();
    bool mint = state.tokenId == 0;
    uint128 liquidityBefore;

    if (params.readBalanceFlag) {
      if (addedAmount0 > state.amount0) {
        addedAmount0 = state.amount0;
      }
      if (addedAmount1 > state.amount1) {
        addedAmount1 = state.amount1;
      }

      /// Settles the added amounts for the position manager, which computes the liquidity from
      /// the credited deltas
      _settleFor(state.poolManager, params.poolKey.currency0, params.posManager, addedAmount0);
      _settleFor(state.poolManager, params.poolKey.currency1, params.posManager, addedAmount1);

      if (!mint) {
        liquidityBefore = IPositionManager(params.posManager).getPositionLiquidity(state.tokenId);
      }
    }

    if (mint) {
      state.tokenId = IPositionManager(params.posManager).nextTokenId();
    }

    bytes memory actions = new bytes(3);
    bytes[] memory actionParams = new bytes[](3);

    if (mint) {
      if (params.readBalanceFlag) {
        actions[0] = bytes1(uint8(Actions.MINT_POSITION_FROM_DELTAS));
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
        actions[0] = bytes1(uint8(Actions.MINT_POSITION));
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
        actions[0] = bytes1(uint8(Actions.INCREASE_LIQUIDITY_FROM_DELTAS));
        actionParams[0] = abi.encode(
          state.tokenId, type(uint128).max, type(uint128).max, params.addLiquidityHookData
        );
      } else {
        actions[0] = bytes1(uint8(Actions.INCREASE_LIQUIDITY));
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

    IPositionManager(params.posManager)
    .modifyLiquiditiesWithoutUnlock{
      value: currency0Native && !params.readBalanceFlag ? addedAmount0 : 0
    }(
      actions, actionParams
    );

    if (params.readBalanceFlag) {
      unchecked {
        liquidity =
          IPositionManager(params.posManager).getPositionLiquidity(state.tokenId) - liquidityBefore;
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

  /// @dev Swaps the remaining amounts as the helper previews and adds them to the position
  function _zapAgain(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    PreviewZapInResult memory preview = abi.decode(
      IZapPreviewHelper(params.zapAgain.helper)
        .previewZapIn(
          abi.encode(
            ZapInFixedParams({
              posManager: params.posManager,
              poolManager: params.poolManager,
              poolKey: params.poolKey,
              tickLower: params.tickLower,
              tickUpper: params.tickUpper,
              sqrtPriceLimit0X96: params.zapAgain.sqrtPriceLimit0X96,
              sqrtPriceLimit1X96: params.zapAgain.sqrtPriceLimit1X96,
              iterations: params.zapAgain.iterations,
              swapHookData: '',
              addLiquidityHookData: '',
              optimizer: address(0),
              optimizeFixedParams: '',
              readBalanceFlag: false
            })
          ),
          abi.encode(PreviewZapInVariableParams({amount0: state.amount0, amount1: state.amount1}))
        ),
      (PreviewZapInResult)
    );

    if (preview.sqrtPriceX96 != preview.sqrtPriceStartX96) {
      bool zeroForOne = preview.sqrtPriceX96 < preview.sqrtPriceStartX96;
      address currencyIn = zeroForOne ? params.poolKey.currency0 : params.poolKey.currency1;
      uint256 amountIn = zeroForOne ? state.amount0 : state.amount1;

      if (params.readBalanceFlag) {
        currencyIn.settle(state.poolManager, address(this), amountIn, false);
        amountIn = uint256(state.poolManager.currencyDelta(address(this), currencyIn));
      }

      BalanceDelta delta = state.poolManager
        .swap(
          params.poolKey,
          SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: preview.sqrtPriceX96
          }),
          params.zapAgain.swapHookData
        );

      if (params.readBalanceFlag) {
        _close(
          state.poolManager,
          params.poolKey.currency0,
          state.poolManager.currencyDelta(address(this), params.poolKey.currency0)
        );
        _close(
          state.poolManager,
          params.poolKey.currency1,
          state.poolManager.currencyDelta(address(this), params.poolKey.currency1)
        );

        state.amount0 = params.poolKey.currency0.selfBalanceMinusOne();
        state.amount1 = params.poolKey.currency1.selfBalanceMinusOne();
      } else {
        state.amount0 = state.amount0.addDelta(delta.amount0());
        state.amount1 = state.amount1.addDelta(delta.amount1());

        _close(state.poolManager, params.poolKey.currency0, delta.amount0());
        _close(state.poolManager, params.poolKey.currency1, delta.amount1());
      }
    }

    if (preview.positionLiquidity != 0) {
      _addLiquidity(params, state, zapInResult);
    }
  }

  /// @dev Pays the pool manager a negative delta of this contract and takes a positive one
  function _close(IPoolManager poolManager, address currency, int256 delta) internal {
    if (delta < 0) {
      currency.settle(poolManager, address(this), uint256(-delta), false);
    } else if (delta > 0) {
      currency.take(poolManager, address(this), uint256(delta), false);
    }
  }

  /// @dev Pays `amount` of `currency` to the pool manager, crediting `recipient` with the amount
  /// that the pool manager received, which can be less for fee-on-transfer tokens
  function _settleFor(IPoolManager poolManager, address currency, address recipient, uint256 amount)
    internal
  {
    if (amount == 0) {
      return;
    }

    if (currency.isNative()) {
      poolManager.settleFor{value: amount}(recipient);
    } else {
      poolManager.sync(currency);
      currency.safeTransfer(address(poolManager), amount);
      poolManager.settleFor(recipient);
    }
  }

  /// @dev The amounts of currency0 and currency1, rounded up, that `liquidity` requires in the
  /// price range at `sqrtPriceX96`
  function _getAmountsForLiquidity(
    uint160 sqrtPriceX96,
    uint160 sqrtPriceAX96,
    uint160 sqrtPriceBX96,
    uint128 liquidity
  ) internal pure returns (uint256 amount0, uint256 amount1) {
    if (sqrtPriceX96 <= sqrtPriceAX96) {
      amount0 = SqrtPriceMath.getAmount0Delta(sqrtPriceAX96, sqrtPriceBX96, liquidity, true);
    } else if (sqrtPriceX96 < sqrtPriceBX96) {
      amount0 = SqrtPriceMath.getAmount0Delta(sqrtPriceX96, sqrtPriceBX96, liquidity, true);
      amount1 = SqrtPriceMath.getAmount1Delta(sqrtPriceAX96, sqrtPriceX96, liquidity, true);
    } else {
      amount1 = SqrtPriceMath.getAmount1Delta(sqrtPriceAX96, sqrtPriceBX96, liquidity, true);
    }
  }
}
