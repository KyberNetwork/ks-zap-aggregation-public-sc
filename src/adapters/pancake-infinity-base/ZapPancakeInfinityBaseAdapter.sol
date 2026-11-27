// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {
  IZapPancakeInfinityBaseAdapter
} from '../../interfaces/adapters/pancake-infinity-base/IZapPancakeInfinityBaseAdapter.sol';
import {
  IZapPancakeInfinityBaseHelper
} from '../../interfaces/adapters/pancake-infinity-base/IZapPancakeInfinityBaseHelper.sol';

import {CallbackDispatcher} from '../../base/CallbackDispatcher.sol';
import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapHelperCaller} from '../../base/ZapHelperCaller.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {LiquidityAction} from '../../types/LiquidityAction.sol';
import {PackedU128} from '../../types/PackedU128.sol';
import {Actions} from '../../vendors/pancake-infinity/Actions.sol';
import {ICLPoolManager} from '../../vendors/pancake-infinity/ICLPoolManager.sol';
import {ICLPositionManager} from '../../vendors/pancake-infinity/ICLPositionManager.sol';
import {IVault} from '../../vendors/pancake-infinity/IVault.sol';
import {PoolKey} from '../../vendors/pancake-infinity/PoolKey.sol';
import {SqrtPriceMath} from '../../vendors/uniswap-v4/SqrtPriceMath.sol';
import {TickMath} from '../../vendors/uniswap-v4/TickMath.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {IAllowanceTransfer} from 'ks-common-sc/src/interfaces/IAllowanceTransfer.sol';
import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';

/**
 * @title ZapPancakeInfinityBaseAdapter
 * @notice Adds liquidity to a Pancake Infinity CL position with the token balances of the account
 * that delegatecalls it, or removes liquidity from a position that account holds
 * @dev AHV2ProxyCallee delegatecalls the adapter, so the balances and the positions are those of
 * the proxy. Adding liquidity runs inside one lock of the vault. The tokens are approved on the
 * Permit2 contract of the position manager. The callbacks of other pools are delegatecalled to the
 * targets that the optimizers register.
 */
contract ZapPancakeInfinityBaseAdapter is
  IZapPancakeInfinityBaseAdapter,
  ImmutableState,
  ZapHelperCaller,
  CallbackDispatcher
{
  using TokenHelper for address;
  using CommonLibrary for *;
  using CalldataDecoder for bytes;

  /// @dev Vault, pool, price bounds, position and amounts of a zap in
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

  /// @param _WETH The wrapped native token
  constructor(address _WETH) ImmutableState(_WETH) {}

  /// @dev Allows the contract to receive native tokens
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

  /// @dev Adds liquidity as described by `data` and `solverData` inside one lock of the vault
  function _zapIn(bytes calldata data, bytes calldata solverData) internal returns (bytes memory) {
    ZapInOwnerParams calldata params;
    assembly ('memory-safe') {
      params := add(data.offset, calldataload(data.offset))
    }

    ZapInSolverParams calldata solverParams;
    assembly ('memory-safe') {
      solverParams := add(solverData.offset, calldataload(solverData.offset))
    }

    if (params.poolKey.currency0.isNative()) {
      WETH.unwrapWETH();
    } else if (
      params.poolKey.currency0 == address(WETH) || params.poolKey.currency1 == address(WETH)
    ) {
      WETH.wrapETH();
    }

    if (solverParams.approvalFlags.at(0) || solverParams.approvalFlags.at(1)) {
      IAllowanceTransfer permit2 = ICLPositionManager(params.posManager).permit2();
      if (solverParams.approvalFlags.at(0)) {
        CommonLibrary.permit2ApproveInf(params.poolKey.currency0, params.posManager, permit2);
      }
      if (solverParams.approvalFlags.at(1)) {
        CommonLibrary.permit2ApproveInf(params.poolKey.currency1, params.posManager, permit2);
      }
    }

    // The lock callback runs both passes. A new position is minted to the proxy.
    bytes memory lockData = abi.encode(data, solverData);
    bytes memory returnData = IVault(params.vault).lock(lockData);

    ZapInResult memory zapInResult = abi.decode(returnData, (ZapInResult));

    // The position is transferred to the recipient after the lock, unless the recipient already
    // owns it.
    if (
      zapInResult.tokenId != 0
        && (params.tokenId == 0
          || IERC721(params.posManager).ownerOf(zapInResult.tokenId) != params.recipient)
    ) {
      IERC721(params.posManager).transferFrom(address(this), params.recipient, zapInResult.tokenId);
    }

    bytes memory result = abi.encode(zapInResult);
    emit ZapIn(result);

    return result;
  }

  /// @inheritdoc IZapPancakeInfinityBaseAdapter
  function lockAcquired(bytes calldata data) external returns (bytes memory) {
    // Runs inside the lock of the vault, which is `msg.sender`; the pool manager of the pool key
    // is the CL pool manager. Both passes call `poolSwap` of the helper of the solver with the
    // same `poolSwap` parameters. The helper runs inside the lock and opens none. The callbacks of
    // an optimizer pool are delegatecalled to the targets that the optimizer registers.
    bytes calldata ownerParamsData = data.decodeBytes(0);
    bytes calldata solverData = data.decodeBytes(1);

    ZapInOwnerParams calldata params;
    assembly ('memory-safe') {
      params := add(ownerParamsData.offset, calldataload(ownerParamsData.offset))
    }

    ZapInSolverParams calldata solverParams;
    assembly ('memory-safe') {
      solverParams := add(solverData.offset, calldataload(solverData.offset))
    }

    ZapInState memory state;
    state.vault = IVault(msg.sender);
    state.clPoolManager = ICLPoolManager(params.poolKey.poolManager);
    state.poolId = params.poolKey.toId();
    state.sqrtPriceLowerX96 = TickMath.getSqrtPriceAtTick(params.tickLower);
    state.sqrtPriceUpperX96 = TickMath.getSqrtPriceAtTick(params.tickUpper);
    state.tokenId = params.tokenId;

    ZapInResult memory zapInResult;
    zapInResult.posManager = params.posManager;
    zapInResult.recipient = params.recipient;
    zapInResult.originalAmount0 = params.poolKey.currency0.selfBalanceMinusOne();
    zapInResult.originalAmount1 = params.poolKey.currency1.selfBalanceMinusOne();

    // First pass: the helper receives the token balances less 1 wei and the extra data. It swaps
    // when `poolSwap.iterations` is not zero and otherwise returns the amounts unchanged. The
    // pass adds the amounts and the liquidity that the helper returns, and reverts when that
    // liquidity is zero.
    uint128 liquidityToAdd = _poolSwap(
      ownerParamsData,
      solverData,
      solverParams.helper,
      state,
      IZapPancakeInfinityBaseHelper.PoolSwapAdditionalParams({
        amount0: zapInResult.originalAmount0,
        amount1: zapInResult.originalAmount1,
        useExtraData: true
      })
    );

    require(liquidityToAdd != 0, ZapInPancakeInfinityInsufficientLiquidity());
    _modifyLiquidity(params, solverParams.readBalanceFlag, liquidityToAdd, state, zapInResult);

    // Second pass: runs when `poolSwap.iterations` is not zero and the leftover of currency0 or
    // currency1 is at least its value in `minZapInAmounts`. The helper receives the leftover
    // balances less 1 wei without the extra data, and the addition is skipped when the liquidity
    // to add is zero. The leftover balances stay in the proxy.
    if (
      solverParams.poolSwap.iterations != 0
        && _reachesMinimums(params.poolKey, solverParams.minZapInAmounts)
    ) {
      liquidityToAdd = _poolSwap(
        ownerParamsData,
        solverData,
        solverParams.helper,
        state,
        IZapPancakeInfinityBaseHelper.PoolSwapAdditionalParams({
          amount0: params.poolKey.currency0.selfBalanceMinusOne(),
          amount1: params.poolKey.currency1.selfBalanceMinusOne(),
          useExtraData: false
        })
      );
      if (liquidityToAdd != 0) {
        _modifyLiquidity(params, solverParams.readBalanceFlag, liquidityToAdd, state, zapInResult);
      }
    }

    // `minLiquidity` is checked on the liquidity added by both passes.
    require(
      zapInResult.addedLiquidity >= params.minLiquidity, ZapInPancakeInfinityInsufficientLiquidity()
    );

    zapInResult.tokenId = state.tokenId;

    // With `readBalanceFlag`, the leftover balances minus 1 are recorded; otherwise the amounts
    // left after the pool swap of the last pass and its addition are recorded.
    if (solverParams.readBalanceFlag) {
      zapInResult.remainingAmount0 = params.poolKey.currency0.selfBalanceMinusOne();
      zapInResult.remainingAmount1 = params.poolKey.currency1.selfBalanceMinusOne();
    } else {
      zapInResult.remainingAmount0 = state.amount0;
      zapInResult.remainingAmount1 = state.amount1;
    }

    return abi.encode(zapInResult);
  }

  /// @dev Returns whether the balance of currency0 or currency1, minus 1, is at least its minimum
  /// in `minZapInAmounts`
  function _reachesMinimums(PoolKey calldata poolKey, PackedU128 minZapInAmounts)
    internal
    view
    returns (bool)
  {
    return poolKey.currency0.selfBalanceMinusOne() >= minZapInAmounts.value0()
      || poolKey.currency1.selfBalanceMinusOne() >= minZapInAmounts.value1();
  }

  /// @dev Calls `helper` with the amounts in `additionalParams`, records the balances after the
  /// swap that it returns in `state` and returns the liquidity they add
  function _poolSwap(
    bytes calldata ownerData,
    bytes calldata solverData,
    address helper,
    ZapInState memory state,
    IZapPancakeInfinityBaseHelper.PoolSwapAdditionalParams memory additionalParams
  ) internal returns (uint128 liquidityToAdd) {
    bytes memory additionalData = abi.encode(additionalParams);

    bytes memory returnData = _poolSwap(helper, ownerData, solverData, additionalData);
    IZapPancakeInfinityBaseHelper.PoolSwapResult memory result =
      abi.decode(abi.decode(returnData, (bytes)), (IZapPancakeInfinityBaseHelper.PoolSwapResult));

    state.amount0 = result.amount0AfterSwap;
    state.amount1 = result.amount1AfterSwap;
    return result.liquidityToAdd;
  }

  /// @dev Removes liquidity as described by `data` and `solverData`, takes the amounts into the
  /// proxy and transfers the position to the recipient unless it is the zero address
  function _remove(bytes calldata data, bytes calldata solverData) internal returns (bytes memory) {
    RemoveOwnerParams calldata params;
    assembly ('memory-safe') {
      params := add(data.offset, calldataload(data.offset))
    }

    PackedU128 minRemoveAmounts = PackedU128.wrap(0);
    if (solverData.length != 0) {
      RemoveSolverParams calldata solverParams;
      assembly ('memory-safe') {
        solverParams := solverData.offset
      }
      minRemoveAmounts = solverParams.minRemoveAmounts;
    }

    (PoolKey memory poolKey,) =
      ICLPositionManager(params.posManager).getPoolAndPositionInfo(params.tokenId);

    uint256 balance0Before = poolKey.currency0.selfBalance();
    uint256 balance1Before = poolKey.currency1.selfBalance();

    bytes memory actions = new bytes(2);
    bytes[] memory actionParams = new bytes[](2);

    actions[0] = bytes1(uint8(Actions.CL_DECREASE_LIQUIDITY));
    actionParams[0] = abi.encode(
      params.tokenId,
      params.liquidity,
      minRemoveAmounts.value0(),
      minRemoveAmounts.value1(),
      params.hookData
    );

    actions[1] = bytes1(uint8(Actions.TAKE_PAIR));
    actionParams[1] = abi.encode(poolKey.currency0, poolKey.currency1, address(this));

    bytes memory payload = abi.encode(actions, actionParams);
    ICLPositionManager(params.posManager).modifyLiquidities(payload, block.timestamp);

    uint256 amount0 = poolKey.currency0.selfBalance() - balance0Before;
    uint256 amount1 = poolKey.currency1.selfBalance() - balance1Before;

    if (params.recipient != address(0)) {
      IERC721(params.posManager).transferFrom(address(this), params.recipient, params.tokenId);
    }

    bytes memory result = abi.encode(
      RemoveResult({
        posManager: params.posManager,
        tokenId: params.tokenId,
        liquidity: params.liquidity,
        amount0: amount0,
        amount1: amount1
      })
    );
    emit RemoveLiquidity(result);

    return result;
  }

  /// @dev Adds liquidity to the position, updates the amounts in `state` and records the addition
  /// in `zapInResult`. The liquidity is `liquidityToAdd`, or with `readBalanceFlag` the liquidity
  /// that the position manager computes from the credited deltas.
  function _modifyLiquidity(
    ZapInOwnerParams calldata params,
    bool readBalanceFlag,
    uint128 liquidityToAdd,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    bool mint = state.tokenId == 0;
    uint256 addedAmount0;
    uint256 addedAmount1;

    uint128 liquidityBefore = 0;
    if (readBalanceFlag) {
      // Settles the full balances for the position manager, which computes the liquidity from
      // the credited deltas. CLOSE_CURRENCY returns the excess to the proxy, and `_readDeltas`
      // derives the added amounts from the balance changes
      _settleFor(state.vault, params.poolKey.currency0, params.posManager, state.amount0);
      _settleFor(state.vault, params.poolKey.currency1, params.posManager, state.amount1);

      if (!mint) {
        liquidityBefore = ICLPositionManager(params.posManager).getPositionLiquidity(state.tokenId);
      }
    } else {
      (addedAmount0, addedAmount1) = _amountsForLiquidity(state, liquidityToAdd);
      if (params.poolKey.currency0.isNative()) {
        // The position manager credits the accrued fees of an increase against the principal. The
        // native amount is settled in full for it, and CLOSE_CURRENCY returns the credited fees
        _settleFor(state.vault, params.poolKey.currency0, params.posManager, addedAmount0);
      }
    }

    bytes memory actions = new bytes(3);
    bytes[] memory actionParams = new bytes[](3);

    if (mint) {
      state.tokenId = ICLPositionManager(params.posManager).nextTokenId();
      (actions[0], actionParams[0]) = _mintAction(params, readBalanceFlag, liquidityToAdd);
    } else {
      (actions[0], actionParams[0]) =
        _increaseLiquidityAction(params, readBalanceFlag, state.tokenId, liquidityToAdd);
    }

    actions[1] = bytes1(uint8(Actions.CLOSE_CURRENCY));
    actionParams[1] = abi.encode(params.poolKey.currency0);

    actions[2] = bytes1(uint8(Actions.CLOSE_CURRENCY));
    actionParams[2] = abi.encode(params.poolKey.currency1);

    ICLPositionManager(params.posManager).modifyLiquiditiesWithoutLock(actions, actionParams);

    uint128 addedLiquidity = liquidityToAdd;
    if (readBalanceFlag) {
      (addedLiquidity, addedAmount0, addedAmount1) = _readDeltas(params, state, liquidityBefore);
    } else {
      unchecked {
        state.amount0 = state.amount0 > addedAmount0 ? state.amount0 - addedAmount0 : 0;
        state.amount1 = state.amount1 > addedAmount1 ? state.amount1 - addedAmount1 : 0;
      }
    }

    unchecked {
      zapInResult.addedLiquidity += addedLiquidity;
      zapInResult.addedAmount0 += addedAmount0;
      zapInResult.addedAmount1 += addedAmount1;
    }
  }

  /**
   * @dev Returns the position manager action that mints the position and its parameters:
   * CL_MINT_POSITION with the liquidity, or CL_MINT_POSITION_FROM_DELTAS with `readBalanceFlag`
   * @param params The owner parameters of the zap in
   * @param readBalanceFlag Whether the position manager mints the liquidity of the settled deltas
   * @param liquidity The liquidity to mint when `readBalanceFlag` is not set
   * @return action The position manager action
   * @return actionParams The ABI-encoded parameters of the action
   */
  function _mintAction(ZapInOwnerParams calldata params, bool readBalanceFlag, uint128 liquidity)
    internal
    view
    returns (bytes1 action, bytes memory actionParams)
  {
    if (readBalanceFlag) {
      action = bytes1(uint8(Actions.CL_MINT_POSITION_FROM_DELTAS));
      actionParams = abi.encode(
        params.poolKey,
        params.tickLower,
        params.tickUpper,
        type(uint128).max,
        type(uint128).max,
        address(this),
        params.addLiquidityHookData
      );
    } else {
      action = bytes1(uint8(Actions.CL_MINT_POSITION));
      actionParams = abi.encode(
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
  }

  /**
   * @dev Returns the position manager action that increases the liquidity of the position and its
   * parameters: CL_INCREASE_LIQUIDITY with the liquidity, or CL_INCREASE_LIQUIDITY_FROM_DELTAS with
   * `readBalanceFlag`
   * @param params The owner parameters of the zap in
   * @param readBalanceFlag Whether the position manager adds the liquidity of the settled deltas
   * @param tokenId The position to increase
   * @param liquidity The liquidity to add when `readBalanceFlag` is not set
   * @return action The position manager action
   * @return actionParams The ABI-encoded parameters of the action
   */
  function _increaseLiquidityAction(
    ZapInOwnerParams calldata params,
    bool readBalanceFlag,
    uint256 tokenId,
    uint128 liquidity
  ) internal pure returns (bytes1 action, bytes memory actionParams) {
    if (readBalanceFlag) {
      action = bytes1(uint8(Actions.CL_INCREASE_LIQUIDITY_FROM_DELTAS));
      actionParams =
        abi.encode(tokenId, type(uint128).max, type(uint128).max, params.addLiquidityHookData);
    } else {
      action = bytes1(uint8(Actions.CL_INCREASE_LIQUIDITY));
      actionParams = abi.encode(
        tokenId, liquidity, type(uint128).max, type(uint128).max, params.addLiquidityHookData
      );
    }
  }

  /**
   * @dev Reads the liquidity added to the position and the amounts spent from the balances, and
   * sets the amounts in `state` to the balances less 1 wei
   * @param params The owner parameters of the zap in
   * @param state The position and the amounts available before the addition
   * @param liquidityBefore The liquidity of the position before the addition
   * @return liquidity The liquidity added
   * @return addedAmount0 The amount of currency0 spent
   * @return addedAmount1 The amount of currency1 spent
   */
  function _readDeltas(
    ZapInOwnerParams calldata params,
    ZapInState memory state,
    uint128 liquidityBefore
  ) internal view returns (uint128 liquidity, uint256 addedAmount0, uint256 addedAmount1) {
    unchecked {
      liquidity =
        ICLPositionManager(params.posManager).getPositionLiquidity(state.tokenId) - liquidityBefore;
    }

    uint256 balance0 = params.poolKey.currency0.selfBalanceMinusOne();
    uint256 balance1 = params.poolKey.currency1.selfBalanceMinusOne();

    unchecked {
      addedAmount0 = state.amount0 > balance0 ? state.amount0 - balance0 : 0;
      addedAmount1 = state.amount1 > balance1 ? state.amount1 - balance1 : 0;
    }

    state.amount0 = balance0;
    state.amount1 = balance1;
  }

  /// @dev Pays `amount` of `currency` to the vault, crediting `recipient` with the amount that
  /// the vault received, which can be less for fee-on-transfer tokens
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
   * @dev Computes the amounts of currency0 and currency1, rounded up, that `liquidity` requires in
   * the price range at the current pool price
   * @param state The pool and the price range
   * @param liquidity The liquidity to add
   * @return addedAmount0 The amount of currency0 the liquidity requires
   * @return addedAmount1 The amount of currency1 the liquidity requires
   */
  function _amountsForLiquidity(ZapInState memory state, uint128 liquidity)
    internal
    view
    returns (uint256 addedAmount0, uint256 addedAmount1)
  {
    (uint160 sqrtPriceX96,,,) = state.clPoolManager.getSlot0(state.poolId);

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
