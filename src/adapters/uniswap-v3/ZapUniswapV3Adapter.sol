// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IZapUniswapV3Adapter} from '../../interfaces/adapters/uniswap-v3/IZapUniswapV3Adapter.sol';
import {IZapUniswapV3Helper} from '../../interfaces/adapters/uniswap-v3/IZapUniswapV3Helper.sol';

import {CallbackDispatcher} from '../../base/CallbackDispatcher.sol';
import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapHelperCaller} from '../../base/ZapHelperCaller.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {LiquidityAction} from '../../types/LiquidityAction.sol';
import {PackedU128} from '../../types/PackedU128.sol';
import {IUniswapV3NFT} from '../../vendors/uniswap-v3/IUniswapV3NFT.sol';
import {IUniswapV3Pool} from '../../vendors/uniswap-v3/IUniswapV3Pool.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';

/**
 * @title ZapUniswapV3Adapter
 * @notice Adds liquidity to a Uniswap V3 position with the token balances of the account that
 * delegatecalls it, or removes liquidity from a position that account holds
 * @dev AHV2ProxyCallee delegatecalls the adapter, so the balances and the positions are those of
 * the proxy. The callbacks of the pools are delegatecalled to the targets that the helper and the
 * optimizers register.
 */
contract ZapUniswapV3Adapter is
  IZapUniswapV3Adapter,
  ImmutableState,
  ZapHelperCaller,
  CallbackDispatcher
{
  using TokenHelper for address;
  using CommonLibrary for *;

  /// @dev Tokens, position and amounts available to add of a zap in
  struct ZapInState {
    address token0;
    address token1;
    uint256 tokenId;
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
      params := add(data.offset, calldataload(data.offset))
    }

    ZapInSolverParams calldata solverParams;
    assembly ('memory-safe') {
      solverParams := add(solverData.offset, calldataload(solverData.offset))
    }

    ZapInState memory state;
    state.token0 = IUniswapV3Pool(params.pool).token0();
    state.token1 = IUniswapV3Pool(params.pool).token1();
    state.tokenId = params.tokenId;

    if (state.token0 == address(WETH) || state.token1 == address(WETH)) {
      WETH.wrapETH();
    }

    ZapInResult memory zapInResult;
    zapInResult.posManager = params.posManager;
    zapInResult.recipient = params.recipient;
    zapInResult.originalAmount0 = state.token0.selfBalanceMinusOne();
    zapInResult.originalAmount1 = state.token1.selfBalanceMinusOne();

    // Both passes call `poolSwap` of the helper of the solver with the same `poolSwap`
    // parameters.
    // First pass: the helper receives the token balances less 1 wei and the extra data. It swaps
    // when `poolSwap.iterations` is not zero and otherwise returns the amounts unchanged. The
    // pass adds the amounts and the liquidity that the helper returns, and reverts when that
    // liquidity is zero.
    uint128 liquidityToAdd = _poolSwap(
      data,
      solverData,
      solverParams.helper,
      state,
      IZapUniswapV3Helper.PoolSwapAdditionalParams({
        amount0: zapInResult.originalAmount0,
        amount1: zapInResult.originalAmount1,
        useExtraData: true
      })
    );

    require(liquidityToAdd != 0, ZapInUniswapV3InsufficientLiquidity());

    if (solverParams.approvalFlags.at(0)) {
      state.token0.forceApproveInf(params.posManager);
    }
    if (solverParams.approvalFlags.at(1)) {
      state.token1.forceApproveInf(params.posManager);
    }
    _modifyPosition(params, state, zapInResult);

    // Second pass: runs when `poolSwap.iterations` is not zero and the leftover of token0 or
    // token1 is at least its value in `minZapInAmounts`. The helper receives the leftover
    // balances less 1 wei without the extra data, and the addition is skipped when the liquidity
    // to add is zero. The leftover balances stay in the proxy.
    if (
      solverParams.poolSwap.iterations != 0 && _reachesMinimums(state, solverParams.minZapInAmounts)
    ) {
      liquidityToAdd = _poolSwap(
        data,
        solverData,
        solverParams.helper,
        state,
        IZapUniswapV3Helper.PoolSwapAdditionalParams({
          amount0: state.token0.selfBalanceMinusOne(),
          amount1: state.token1.selfBalanceMinusOne(),
          useExtraData: false
        })
      );
      if (liquidityToAdd != 0) {
        _modifyPosition(params, state, zapInResult);
      }
    }

    // `minLiquidity` is checked on the liquidity added by both passes.
    require(
      zapInResult.addedLiquidity >= params.minLiquidity, ZapInUniswapV3InsufficientLiquidity()
    );

    zapInResult.tokenId = state.tokenId;

    if (
      params.tokenId != 0 && IERC721(params.posManager).ownerOf(params.tokenId) != params.recipient
    ) {
      IERC721(params.posManager).transferFrom(address(this), params.recipient, params.tokenId);
    }

    // The amounts left after the pool swap of the last pass and its addition are recorded.
    zapInResult.remainingAmount0 = state.amount0;
    zapInResult.remainingAmount1 = state.amount1;

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
  /// swap that it returns in `state` and returns the liquidity they add
  function _poolSwap(
    bytes calldata ownerData,
    bytes calldata solverData,
    address helper,
    ZapInState memory state,
    IZapUniswapV3Helper.PoolSwapAdditionalParams memory additionalParams
  ) internal returns (uint128 liquidityToAdd) {
    bytes memory additionalData = abi.encode(additionalParams);

    bytes memory returnData = _poolSwap(helper, ownerData, solverData, additionalData);
    IZapUniswapV3Helper.PoolSwapResult memory result =
      abi.decode(abi.decode(returnData, (bytes)), (IZapUniswapV3Helper.PoolSwapResult));

    state.amount0 = result.amount0AfterSwap;
    state.amount1 = result.amount1AfterSwap;
    return result.liquidityToAdd;
  }

  /// @dev Removes liquidity as described by `data` and `solverData`, collects the owed amounts into
  /// the proxy and transfers the position to the recipient unless it is the zero address
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

    if (params.liquidity > 0) {
      IUniswapV3NFT(params.posManager)
        .decreaseLiquidity(
          IUniswapV3NFT.DecreaseLiquidityParams({
            tokenId: params.tokenId,
            liquidity: params.liquidity,
            amount0Min: minRemoveAmounts.value0(),
            amount1Min: minRemoveAmounts.value1(),
            deadline: block.timestamp
          })
        );
    }

    (uint256 amount0, uint256 amount1) = IUniswapV3NFT(params.posManager)
      .collect(
        IUniswapV3NFT.CollectParams({
          tokenId: params.tokenId,
          recipient: address(this),
          amount0Max: type(uint128).max,
          amount1Max: type(uint128).max
        })
      );

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

  /// @dev Mints the position or increases its liquidity with the amounts in `state`, deducts the
  /// added amounts from `state` and records the addition in `zapInResult`
  function _modifyPosition(
    ZapInOwnerParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    uint256 liquidity;
    uint256 addedAmount0;
    uint256 addedAmount1;
    if (state.tokenId == 0) {
      (state.tokenId, liquidity, addedAmount0, addedAmount1) = _mint(params, state);
    } else {
      (liquidity, addedAmount0, addedAmount1) = _increaseLiquidity(params, state);
    }

    unchecked {
      state.amount0 -= addedAmount0;
      state.amount1 -= addedAmount1;
      zapInResult.addedLiquidity += liquidity;
      zapInResult.addedAmount0 += addedAmount0;
      zapInResult.addedAmount1 += addedAmount1;
    }
  }

  /// @dev Mints a new position to the recipient with the amounts in `state`
  function _mint(ZapInOwnerParams calldata params, ZapInState memory state)
    internal
    virtual
    returns (uint256 tokenId, uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    return IUniswapV3NFT(params.posManager)
      .mint(
        IUniswapV3NFT.MintParams({
          token0: state.token0,
          token1: state.token1,
          fee: IUniswapV3Pool(params.pool).fee(),
          tickLower: params.tickLower,
          tickUpper: params.tickUpper,
          amount0Desired: state.amount0,
          amount1Desired: state.amount1,
          amount0Min: 0,
          amount1Min: 0,
          recipient: params.recipient,
          deadline: block.timestamp
        })
      );
  }

  /// @dev Adds the amounts in `state` to the position `state.tokenId`
  function _increaseLiquidity(ZapInOwnerParams calldata params, ZapInState memory state)
    internal
    virtual
    returns (uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    return IUniswapV3NFT(params.posManager)
      .increaseLiquidity(
        IUniswapV3NFT.IncreaseLiquidityParams({
          tokenId: state.tokenId,
          amount0Desired: state.amount0,
          amount1Desired: state.amount1,
          amount0Min: 0,
          amount1Min: 0,
          deadline: block.timestamp
        })
      );
  }
}
