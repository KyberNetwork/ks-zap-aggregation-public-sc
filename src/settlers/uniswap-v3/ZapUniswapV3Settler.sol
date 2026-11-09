// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IKSGenericRouter} from '../../interfaces/IKSGenericRouter.sol';
import {IZapUniswapV3Settler} from '../../interfaces/settlers/uniswap-v3/IZapUniswapV3Settler.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {ZapAgainHelperCaller} from '../../base/ZapAgainHelperCaller.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {IUniswapV3NFT} from '../../vendors/uniswap-v3/IUniswapV3NFT.sol';
import {IUniswapV3Pool} from '../../vendors/uniswap-v3/IUniswapV3Pool.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';
import {
  ReentrancyGuardTransient
} from 'openzeppelin-contracts/contracts/utils/ReentrancyGuardTransient.sol';

/// @title ZapUniswapV3Settler
/// @notice Adds liquidity to a Uniswap V3 position with the token balances this contract holds, in
/// an owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of each token is retained. The
/// swap callbacks of the zap again are forwarded to the helper.
contract ZapUniswapV3Settler is
  IZapUniswapV3Settler,
  ImmutableState,
  ZapAgainHelperCaller,
  ReentrancyGuardTransient
{
  using TokenHelper for address;
  using CommonLibrary for *;

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
    _forwardSwapCallback();
  }

  /// @inheritdoc IKSGenericRouter
  function ksExecute(bytes calldata data) external payable nonReentrant returns (bytes memory) {
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

    if (
      params.zapAgain.helper != address(0)
        && (state.amount0 >= params.zapAgain.minZapInAmounts.value0()
          || state.amount1 >= params.zapAgain.minZapInAmounts.value1())
    ) {
      _zapAgain(params, state, zapInResult);
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

  /// @dev Adds the amounts in `state` to the position and records the addition in `zapInResult`
  function _addLiquidity(
    ZapInParams calldata params,
    ZapInState memory state,
    ZapInResult memory zapInResult
  ) internal {
    uint256 liquidity;
    uint256 addedAmount0;
    uint256 addedAmount1;
    if (state.tokenId == 0) {
      (state.tokenId, liquidity, addedAmount0, addedAmount1) =
        _mint(params, state.token0, state.token1, state.amount0, state.amount1);
    } else {
      (liquidity, addedAmount0, addedAmount1) =
        _increaseLiquidity(params, state.tokenId, state.amount0, state.amount1);
    }

    unchecked {
      state.amount0 -= addedAmount0;
      state.amount1 -= addedAmount1;
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
    PoolSwapResult memory swapResult = abi.decode(
      _poolSwap(
        params.zapAgain.helper,
        abi.encode(
          ZapInFixedParams({
            posManager: params.posManager,
            pool: params.pool,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            sqrtPriceLimit0X96: params.zapAgain.sqrtPriceLimit0X96,
            sqrtPriceLimit1X96: params.zapAgain.sqrtPriceLimit1X96,
            iterations: params.zapAgain.iterations,
            optimizer: address(0),
            optimizeFixedParams: ''
          })
        ),
        abi.encode(PoolSwapVariableParams({extraData: ''}))
      ),
      (PoolSwapResult)
    );

    state.amount0 = swapResult.amount0;
    state.amount1 = swapResult.amount1;

    if (swapResult.positionLiquidity != 0) {
      _addLiquidity(params, state, zapInResult);
    }
  }

  /// @dev Mints a new position to the recipient with the given amounts
  function _mint(
    ZapInParams calldata params,
    address token0,
    address token1,
    uint256 amount0,
    uint256 amount1
  )
    internal
    virtual
    returns (uint256 tokenId, uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    return IUniswapV3NFT(params.posManager)
      .mint(
        IUniswapV3NFT.MintParams({
          token0: token0,
          token1: token1,
          fee: IUniswapV3Pool(params.pool).fee(),
          tickLower: params.tickLower,
          tickUpper: params.tickUpper,
          amount0Desired: amount0,
          amount1Desired: amount1,
          amount0Min: 0,
          amount1Min: 0,
          recipient: params.recipient,
          deadline: block.timestamp
        })
      );
  }

  /// @dev Adds the given amounts to the position `tokenId`
  function _increaseLiquidity(
    ZapInParams calldata params,
    uint256 tokenId,
    uint256 amount0,
    uint256 amount1
  ) internal virtual returns (uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1) {
    return IUniswapV3NFT(params.posManager)
      .increaseLiquidity(
        IUniswapV3NFT.IncreaseLiquidityParams({
          tokenId: tokenId,
          amount0Desired: amount0,
          amount1Desired: amount1,
          amount0Min: 0,
          amount1Min: 0,
          deadline: block.timestamp
        })
      );
  }
}
