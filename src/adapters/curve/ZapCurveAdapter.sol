// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IZapCurveAdapter} from '../../interfaces/adapters/curve/IZapCurveAdapter.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {LiquidityAction} from '../../types/LiquidityAction.sol';
import {ICurveStableSwap} from '../../vendors/curve/ICurveStableSwap.sol';
import {ICurveTricrypto} from '../../vendors/curve/ICurveTricrypto.sol';
import {ICurveTwocrypto} from '../../vendors/curve/ICurveTwocrypto.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/**
 * @title ZapCurveAdapter
 * @notice Adds liquidity to a Curve pool with the coin balances of the account that delegatecalls
 * it, or removes LP tokens that account holds
 * @dev AHV2ProxyCallee delegatecalls the adapter, so the balances are those of the proxy.
 */
contract ZapCurveAdapter is IZapCurveAdapter, ImmutableState {
  using TokenHelper for address;
  using CommonLibrary for *;

  /// @param _WETH The wrapped native token
  constructor(address _WETH) ImmutableState(_WETH) {}

  /// @dev Accepts native balance
  receive() external payable {}

  /**
   * @inheritdoc IAHV2Callee
   * @dev `ownerData` is `abi.encodePacked(LiquidityAction action, bytes actionParams)`: the
   * first byte is the action and the remaining bytes are the action parameters. For
   * `ADD_LIQUIDITY`, `actionParams` is `abi.encode(ZapInOwnerParams)` and `solverData` is not
   * read. For `REMOVE_LIQUIDITY`, `actionParams` is `abi.encode(RemoveOwnerParams)` and
   * `solverData` is either empty, which sets no minimum amount, or
   * `abi.encode(RemoveSolverParams)`. An invalid action byte reverts with the panic code 0x21.
   */
  function execute(bytes calldata ownerData, bytes calldata solverData)
    external
    payable
    returns (bytes memory)
  {
    LiquidityAction action = LiquidityAction(uint8(ownerData[0]));
    bytes calldata actionParams = ownerData[1:];

    if (action == LiquidityAction.ADD_LIQUIDITY) {
      return _zapIn(actionParams);
    }
    return _remove(actionParams, solverData);
  }

  /// @dev Adds the coin balances to the pool described by `data` and transfers the LP tokens to the
  /// recipient
  function _zapIn(bytes calldata data) internal returns (bytes memory) {
    ZapInOwnerParams calldata params;
    assembly ('memory-safe') {
      params := data.offset
    }

    address[] memory coins = _coins(params.poolType, params.pool);

    // A pool of the wrapped native token receives the native balance wrapped. A pool of the native
    // coin receives the wrapped native token unwrapped, less 1 wei.
    bool hasWETH = false;
    bool hasNative = false;
    for (uint256 i = 0; i < coins.length; i++) {
      if (coins[i] == address(WETH)) {
        hasWETH = true;
      } else if (coins[i].isNative()) {
        hasNative = true;
      }
    }
    if (hasWETH) {
      WETH.wrapETH();
    } else if (hasNative) {
      WETH.unwrapWETH();
    }

    ZapInResult memory zapInResult;
    zapInResult.pool = params.pool;
    zapInResult.recipient = params.recipient;
    zapInResult.addedAmounts = new uint256[](coins.length);

    // The pool takes the amounts in any ratio, so the adapter adds the balance of each coin less
    // 1 wei and swaps nothing. The native coin is sent as call value.
    uint256 nativeValue = 0;
    for (uint256 i = 0; i < coins.length; i++) {
      zapInResult.addedAmounts[i] = coins[i].selfBalanceMinusOne();
      if (coins[i].isNative()) {
        nativeValue += zapInResult.addedAmounts[i];
      } else {
        coins[i].forceApproveInf(params.pool);
      }
    }

    // The pool runs with a zero minimum and mints the LP tokens to the proxy; the adapter checks
    // them against `minLiquidity` and transfers them to the recipient.
    zapInResult.addedLiquidity =
      _addLiquidity(params.poolType, params.pool, zapInResult.addedAmounts, nativeValue);
    require(
      zapInResult.addedLiquidity != 0 && zapInResult.addedLiquidity >= params.minLiquidity,
      ZapInCurveInsufficientLiquidity()
    );
    _getLpToken(params.pool).safeTransfer(params.recipient, zapInResult.addedLiquidity);

    bytes memory result = abi.encode(zapInResult);
    emit ZapIn(result);

    return result;
  }

  /// @dev Removes the LP tokens described by `data` into the proxy and checks the received amounts
  /// against the minimums of `solverData`
  function _remove(bytes calldata data, bytes calldata solverData) internal returns (bytes memory) {
    RemoveOwnerParams calldata params;
    assembly ('memory-safe') {
      params := data.offset
    }

    address[] memory coins = _coins(params.poolType, params.pool);
    uint256[] memory balancesBefore = new uint256[](coins.length);
    for (uint256 i = 0; i < coins.length; i++) {
      balancesBefore[i] = coins[i].selfBalance();
    }

    // The pool burns `liquidity` LP tokens of the proxy and transfers the coins to the proxy with
    // zero minimums. The amounts are the balance increases, which exclude the transfer rounding of
    // a rebasing coin.
    _removeLiquidity(params.poolType, params.pool, params.liquidity, coins.length);

    RemoveResult memory removeResult;
    removeResult.pool = params.pool;
    removeResult.liquidity = params.liquidity;
    removeResult.amounts = new uint256[](coins.length);
    for (uint256 i = 0; i < coins.length; i++) {
      removeResult.amounts[i] = coins[i].selfBalance() - balancesBefore[i];
    }

    // Empty solver data sets no minimum. Otherwise each coin has a minimum, and an array shorter
    // than the coins reverts.
    if (solverData.length != 0) {
      RemoveSolverParams calldata solverParams;
      assembly ('memory-safe') {
        solverParams := add(solverData.offset, calldataload(solverData.offset))
      }
      for (uint256 i = 0; i < coins.length; i++) {
        require(
          removeResult.amounts[i] >= solverParams.minRemoveAmounts[i],
          RemoveCurveInsufficientAmounts()
        );
      }
    }

    bytes memory result = abi.encode(removeResult);
    emit RemoveLiquidity(result);

    return result;
  }

  /// @dev Returns the coins of the pool: `N_COINS` of a STABLESWAP_NG pool, three of a TRICRYPTO
  /// pool and two otherwise
  function _coins(CurvePoolType poolType, address pool)
    internal
    view
    returns (address[] memory coins)
  {
    uint256 coinCount;
    if (poolType == CurvePoolType.STABLESWAP_NG) {
      coinCount = ICurveStableSwap(pool).N_COINS();
    } else if (poolType == CurvePoolType.TRICRYPTO) {
      coinCount = 3;
    } else {
      coinCount = 2;
    }

    coins = new address[](coinCount);
    for (uint256 i = 0; i < coinCount; i++) {
      coins[i] = ICurveStableSwap(pool).coins(i);
    }
  }

  /// @dev Calls `add_liquidity` of the pool with a zero minimum and returns the LP tokens minted;
  /// only a TWOCRYPTO pool receives `nativeValue`
  function _addLiquidity(
    CurvePoolType poolType,
    address pool,
    uint256[] memory amounts,
    uint256 nativeValue
  ) internal returns (uint256 liquidity) {
    if (poolType == CurvePoolType.STABLESWAP_NG) {
      liquidity = ICurveStableSwap(pool).add_liquidity(amounts, 0);
    } else if (poolType == CurvePoolType.TRICRYPTO) {
      liquidity = ICurveTricrypto(pool).add_liquidity([amounts[0], amounts[1], amounts[2]], 0);
    } else {
      liquidity =
        ICurveTwocrypto(pool).add_liquidity{value: nativeValue}([amounts[0], amounts[1]], 0);
    }
  }

  /// @dev Calls `remove_liquidity` of the pool with zero minimums
  function _removeLiquidity(
    CurvePoolType poolType,
    address pool,
    uint256 liquidity,
    uint256 coinCount
  ) internal {
    if (poolType == CurvePoolType.STABLESWAP_NG) {
      uint256[] memory zeroMinimums = new uint256[](coinCount);
      ICurveStableSwap(pool).remove_liquidity(liquidity, zeroMinimums);
    } else if (poolType == CurvePoolType.TRICRYPTO) {
      ICurveTricrypto(pool).remove_liquidity(liquidity, [uint256(0), 0, 0]);
    } else {
      ICurveTwocrypto(pool).remove_liquidity(liquidity, [uint256(0), 0]);
    }
  }

  /// @dev Returns the LP token of the pool, which is the pool itself when it has no `token` getter
  function _getLpToken(address pool) internal view returns (address) {
    bytes memory callData = abi.encodeCall(ICurveTricrypto.token, ());
    (bool success, bytes memory data) = pool.staticcall(callData);

    if (success && data.length == 32) {
      return abi.decode(data, (address));
    } else {
      return pool;
    }
  }
}
