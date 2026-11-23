// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IKSZapExecutor} from '../../interfaces/IKSZapExecutor.sol';
import {IZapPoolSwapAgainHelper} from '../../interfaces/adapters/IZapPoolSwapAgainHelper.sol';
import {IZapUniswapV3Adapter} from '../../interfaces/adapters/uniswap-v3/IZapUniswapV3Adapter.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapAgainHelperCaller} from '../../base/ZapAgainHelperCaller.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {ZapAgainRecord} from '../../libraries/ZapAgainRecord.sol';
import {IUniswapV3NFT} from '../../vendors/uniswap-v3/IUniswapV3NFT.sol';
import {IUniswapV3Pool} from '../../vendors/uniswap-v3/IUniswapV3Pool.sol';
import {LiquidityAmounts} from '../../vendors/uniswap-v4/LiquidityAmounts.sol';
import {TickMath} from '../../vendors/uniswap-v4/TickMath.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';
import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

/// @title ZapUniswapV3Adapter
/// @notice Adds liquidity to a Uniswap V3 position with the token balances this contract holds,
/// when KSZapRouterV3 delegatecalls it in an owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained. The
/// swap callbacks of the zap again are forwarded to the helper.
contract ZapUniswapV3Adapter is IZapUniswapV3Adapter, ImmutableState, ZapAgainHelperCaller {
  using TokenHelper for address;
  using CommonLibrary for *;
  using Address for address;

  /// @dev Tokens and amounts of a zap in
  struct ZapInState {
    address token0;
    address token1;
    uint256 tokenId;
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
      params := add(data.offset, calldataload(data.offset))
    }

    ZapInState memory state;
    state.token0 = IUniswapV3Pool(params.pool).token0();
    state.token1 = IUniswapV3Pool(params.pool).token1();
    state.tokenId = params.tokenId;

    if (state.token0 == address(WETH) || state.token1 == address(WETH)) {
      WETH.wrapETH();
    }

    state.amount0 = state.token0.selfBalanceMinusOne();
    state.amount1 = state.token1.selfBalanceMinusOne();

    ZapInResult memory zapInResult;
    zapInResult.posManager = params.posManager;
    zapInResult.recipient = params.recipient;
    zapInResult.originalAmount0 = state.amount0;
    zapInResult.originalAmount1 = state.amount1;

    if (params.approvalFlags.at(0)) {
      state.token0.forceApproveInf(params.posManager);
    }
    if (params.approvalFlags.at(1)) {
      state.token1.forceApproveInf(params.posManager);
    }

    _addLiquidity(params, state, zapInResult);

    if (zapAgainParams.length != 0 && params.helper != address(0)) {
      _zapAgain(params, state, zapInResult, zapAgainParams);
    }

    require(
      zapInResult.positionLiquidity >= params.minLiquidity, ZapInUniswapV3InsufficientLiquidity()
    );

    zapInResult.tokenId = state.tokenId;

    if (
      params.tokenId != 0 && IERC721(params.posManager).ownerOf(params.tokenId) != params.recipient
    ) {
      IERC721(params.posManager).transferFrom(address(this), params.recipient, params.tokenId);
    }

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

  /// @dev Adds the amounts in `state` to the position and records the addition in `zapInResult`.
  /// Returns without calling the position manager when the amounts add no liquidity.
  function _addLiquidity(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    uint256 addableLiquidity = LiquidityAmounts.getLiquidityForAmounts(
      _getSqrtPriceX96(params.pool),
      TickMath.getSqrtPriceAtTick(params.tickLower),
      TickMath.getSqrtPriceAtTick(params.tickUpper),
      state.amount0,
      state.amount1
    );
    if (addableLiquidity == 0) {
      return;
    }

    _modifyPosition(params, state, zapInResult);
  }

  /// @dev Mints the position or increases its liquidity with the amounts in `state` and records
  /// the addition in `zapInResult`
  function _modifyPosition(
    ZapInParams calldata params,
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
      zapInResult.positionLiquidity += liquidity;
      zapInResult.addedAmount0 += addedAmount0;
      zapInResult.addedAmount1 += addedAmount1;
    }
  }

  /// @dev Swaps the remaining amounts through the helper with the recorded configuration and adds
  /// the liquidity it returns to the position
  function _zapAgain(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult,
    bytes memory zapAgainParams
  ) internal {
    UniswapV3ZapAgainParams memory zapAgain = abi.decode(zapAgainParams, (UniswapV3ZapAgainParams));

    bytes memory fixedParams = abi.encode(
      ZapInFixedParams({
        posManager: params.posManager,
        pool: params.pool,
        tickLower: params.tickLower,
        tickUpper: params.tickUpper,
        sqrtPriceLimit0X96: zapAgain.sqrtPriceLimit0X96,
        sqrtPriceLimit1X96: zapAgain.sqrtPriceLimit1X96,
        iterations: zapAgain.iterations,
        optimizer: zapAgain.optimizer,
        optimizeFixedParams: zapAgain.optimizeFixedParams
      })
    );

    IZapPoolSwapAgainHelper.PoolSwapAgainResult memory result =
      _poolSwapAgain(params.helper, fixedParams, zapAgain.minZapInAmounts);

    if (result.liquidity == 0) {
      return;
    }

    state.amount0 = result.amount0;
    state.amount1 = result.amount1;

    _modifyPosition(params, state, zapInResult);
  }

  /// @dev Reads the leading price word of the `slot0` getter of the pool
  function _getSqrtPriceX96(address pool) internal view virtual returns (uint160 sqrtPriceX96) {
    bytes memory callData = abi.encodeWithSelector(IUniswapV3Pool.slot0.selector);
    bytes memory returnData = pool.functionStaticCall(callData);
    assembly ('memory-safe') {
      sqrtPriceX96 := mload(add(returnData, 0x20))
    }
  }

  /// @dev Mints a new position to the recipient with the given amounts
  function _mint(ZapInParams calldata params, ZapInState memory state)
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

  /// @dev Adds the given amounts to the position `tokenId`
  function _increaseLiquidity(ZapInParams calldata params, ZapInState memory state)
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
