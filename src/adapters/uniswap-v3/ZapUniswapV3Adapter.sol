// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IZapUniswapV3Adapter} from '../../interfaces/adapters/uniswap-v3/IZapUniswapV3Adapter.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapHelperCaller} from '../../base/ZapHelperCaller.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {LiquidityAction} from '../../types/LiquidityAction.sol';
import {PackedU128} from '../../types/PackedU128.sol';
import {IUniswapV3NFT} from '../../vendors/uniswap-v3/IUniswapV3NFT.sol';
import {IUniswapV3Pool} from '../../vendors/uniswap-v3/IUniswapV3Pool.sol';
import {LiquidityAmounts} from '../../vendors/uniswap-v4/LiquidityAmounts.sol';
import {TickMath} from '../../vendors/uniswap-v4/TickMath.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';

/**
 * @title ZapUniswapV3Adapter
 * @notice Adds liquidity to a Uniswap V3 position with the token balances of the account that
 * delegatecalls it, or removes liquidity from a position that account holds
 * @dev AHV2ProxyCallee delegatecalls the adapter, so the balances and the positions are those of
 * the proxy. Adding liquidity runs up to two passes. The first pass swaps with the helper of the
 * solver when the helper is set and `poolSwap.iterations` is not zero, and adds the resulting
 * amounts; otherwise it adds the token balances. It reverts with
 * `ZapInUniswapV3InsufficientLiquidity` when it adds no liquidity. The second pass runs only when
 * the helper is set and the leftover of token0 or token1 is at least its value in
 * `minZapInAmounts`; it swaps with `poolSwapAgain` and skips its addition when the liquidity to
 * add is zero. 1 wei of each token is kept when adding liquidity, and the leftover balances stay in
 * the proxy. The fallback forwards the swap callbacks of the pool swaps to the helper.
 */
contract ZapUniswapV3Adapter is IZapUniswapV3Adapter, ImmutableState, ZapHelperCaller {
  using TokenHelper for address;
  using CommonLibrary for *;
  using CalldataDecoder for bytes;

  /// @dev Tokens, amounts to add and position of a zap in
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

  /// @dev Forwards the swap callbacks of the pool swaps to the helper
  fallback() external {
    _forwardUniswapV3SwapCallback();
  }

  /**
   * @inheritdoc IAHV2Callee
   * @dev `ownerData` is `abi.encode(LiquidityAction action, bytes actionParams)`. For
   * `ADD_LIQUIDITY`, `actionParams` is `abi.encode(ZapInOwnerParams)` and `solverData` is the
   * required `abi.encode(ZapInSolverParams)`. For `REMOVE_LIQUIDITY`, `actionParams` is
   * `abi.encode(RemoveOwnerParams)` and `solverData` is either empty, which sets the minimum
   * amounts to zero, or `abi.encode(RemoveSolverParams)`.
   */
  function execute(bytes calldata ownerData, bytes calldata solverData)
    external
    payable
    returns (bytes memory)
  {
    LiquidityAction action = LiquidityAction(ownerData.decodeUint256(0));
    bytes calldata actionParams = ownerData.decodeBytes(1);

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

    uint256 liquidityToAdd;
    if (solverParams.helper != address(0) && solverParams.poolSwap.iterations != 0) {
      liquidityToAdd = _poolSwap(params, state, solverParams.helper, solverParams.poolSwap);
    } else {
      state.amount0 = zapInResult.originalAmount0;
      state.amount1 = zapInResult.originalAmount1;
      liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
        _getSqrtPriceX96(params.pool),
        TickMath.getSqrtPriceAtTick(params.tickLower),
        TickMath.getSqrtPriceAtTick(params.tickUpper),
        state.amount0,
        state.amount1
      );
    }

    require(liquidityToAdd != 0, ZapInUniswapV3InsufficientLiquidity());

    if (solverParams.approvalFlags.at(0)) {
      state.token0.forceApproveInf(params.posManager);
    }
    if (solverParams.approvalFlags.at(1)) {
      state.token1.forceApproveInf(params.posManager);
    }
    _modifyPosition(params, state, zapInResult);

    if (solverParams.helper != address(0) && _reachesMinimums(state, solverParams.minZapInAmounts))
    {
      liquidityToAdd = _poolSwap(params, state, solverParams.helper, solverParams.poolSwapAgain);
      if (liquidityToAdd != 0) {
        _modifyPosition(params, state, zapInResult);
      }
    }

    require(
      zapInResult.addedLiquidity >= params.minLiquidity, ZapInUniswapV3InsufficientLiquidity()
    );

    zapInResult.tokenId = state.tokenId;

    if (
      params.tokenId != 0 && IERC721(params.posManager).ownerOf(params.tokenId) != params.recipient
    ) {
      IERC721(params.posManager).transferFrom(address(this), params.recipient, params.tokenId);
    }

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

  /// @dev Swaps the balances through the helper towards the ratio of the position, as described by
  /// `poolSwapParams`, records the amounts to add in `state` and returns the liquidity they add
  function _poolSwap(
    ZapInOwnerParams calldata params,
    ZapInState memory state,
    address helper,
    UniswapV3PoolSwapParams calldata poolSwapParams
  ) internal returns (uint256 liquidityToAdd) {
    bytes memory fixedParams = abi.encode(
      ZapInFixedParams({
        posManager: params.posManager,
        pool: params.pool,
        tickLower: params.tickLower,
        tickUpper: params.tickUpper,
        sqrtPriceLimit0X96: poolSwapParams.sqrtPriceLimit0X96,
        sqrtPriceLimit1X96: poolSwapParams.sqrtPriceLimit1X96,
        iterations: poolSwapParams.iterations,
        optimizer: poolSwapParams.optimizer,
        optimizeFixedParams: poolSwapParams.optimizeFixedParams
      })
    );
    bytes memory variableParams =
      abi.encode(PoolSwapVariableParams({extraData: poolSwapParams.extraData}));

    bytes memory returnData = _poolSwap(helper, fixedParams, variableParams);
    PoolSwapResult memory result = abi.decode(abi.decode(returnData, (bytes)), (PoolSwapResult));

    state.amount0 = result.amount0ToAdd;
    state.amount1 = result.amount1ToAdd;
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

    require(
      amount0 >= minRemoveAmounts.value0() && amount1 >= minRemoveAmounts.value1(),
      RemoveUniswapV3InsufficientAmounts()
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

  /// @dev Staticcalls the `slot0` getter of the pool and returns the first word of its return
  /// data, the sqrt price. Reverts with the return data of the pool when the call fails or returns
  /// less than one word.
  function _getSqrtPriceX96(address pool) internal view virtual returns (uint160 sqrtPriceX96) {
    bytes4 selector = IUniswapV3Pool.slot0.selector;
    assembly ('memory-safe') {
      mstore(0, selector)
      let success := staticcall(gas(), pool, 0, 4, 0, 0x20)
      if or(iszero(success), lt(returndatasize(), 0x20)) {
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
      sqrtPriceX96 := mload(0)
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
