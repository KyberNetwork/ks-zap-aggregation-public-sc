// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IZapHelper} from '../interfaces/adapters/IZapHelper.sol';
import {IZapLegacyPoolSwapHelper} from '../interfaces/adapters/IZapLegacyPoolSwapHelper.sol';
import {IZapPoolSwapAgainHelper} from '../interfaces/adapters/IZapPoolSwapAgainHelper.sol';
import {MASK_BYTES_4} from '../libraries/BitMask.sol';
import {PackedU128} from '../types/PackedU128.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {TransientSlot} from 'openzeppelin-contracts/contracts/utils/TransientSlot.sol';

/// @title ZapHelperCaller
/// @notice Delegatecalls a helper to run a pool swap and forwards the callbacks of that swap to the
/// helper
/// @dev The helper runs in the context of this contract with its balances. The helper is recorded
/// in a transient slot so that callbacks of the pool reach it: an adapter whose pools call back
/// sets it with `_setHelper` before its first pool swap and clears it with `_clearHelper` after
/// its last one, and the calls to `IZapLegacyPoolSwapHelper` and `IZapPoolSwapAgainHelper` record
/// it for the duration of each delegatecall.
abstract contract ZapHelperCaller {
  using TransientSlot for *;

  /// @dev Transient slot holding the helper of the ongoing delegatecall
  bytes32 private constant HELPER_SLOT = bytes32(erc7201('ks.zap.adapter.helper'));

  /// @dev Records `helper` as the helper of the pool swaps that follow
  function _setHelper(address helper) internal {
    HELPER_SLOT.asAddress().tstore(helper);
  }

  /// @dev Clears the recorded helper
  function _clearHelper() internal {
    HELPER_SLOT.asAddress().tstore(address(0));
  }

  /// @dev Delegatecalls `poolSwap` of `helper` with the owner, solver and additional data and
  /// returns its result, without recording the helper. Reverts when `helper` has no code.
  function _poolSwap(
    address helper,
    bytes calldata ownerData,
    bytes calldata solverData,
    bytes memory additionalData
  ) internal returns (bytes memory) {
    bytes memory data = abi.encodeCall(IZapHelper.poolSwap, (ownerData, solverData, additionalData));

    return Address.functionDelegateCall(helper, data);
  }

  /// @dev Delegatecalls `poolSwap` of the helper with the fixed and variable parameters and
  /// returns its result
  function _poolSwap(address helper, bytes memory fixedParams, bytes memory variableParams)
    internal
    returns (bytes memory)
  {
    bytes memory data =
      abi.encodeCall(IZapLegacyPoolSwapHelper.poolSwap, (fixedParams, variableParams));

    return _delegateToHelper(helper, data);
  }

  /// @dev Delegatecalls `poolSwapAgain` of the helper and returns its decoded result
  function _poolSwapAgain(address helper, bytes memory fixedParams, PackedU128 minZapInAmounts)
    internal
    returns (IZapPoolSwapAgainHelper.PoolSwapAgainResult memory result)
  {
    bytes memory data =
      abi.encodeCall(IZapPoolSwapAgainHelper.poolSwapAgain, (fixedParams, minZapInAmounts));

    bytes memory returnData = _delegateToHelper(helper, data);

    result = abi.decode(returnData, (IZapPoolSwapAgainHelper.PoolSwapAgainResult));
  }

  /// @dev Delegatecalls the helper with `data` while the helper is recorded as the helper of the
  /// ongoing pool swap, and returns the raw return data
  function _delegateToHelper(address helper, bytes memory data)
    private
    returns (bytes memory returnData)
  {
    HELPER_SLOT.asAddress().tstore(helper);
    returnData = Address.functionDelegateCall(helper, data);
    HELPER_SLOT.asAddress().tstore(address(0));
  }

  /// @dev Delegatecalls the helper of the ongoing pool swap with `data` and returns the raw return
  /// data to the caller of this contract
  function _forwardCallback(bytes memory data) internal {
    address helper = HELPER_SLOT.asAddress().tload();

    bytes memory returnData = Address.functionDelegateCall(helper, data);
    assembly ('memory-safe') {
      return(add(returnData, 0x20), mload(returnData))
    }
  }

  /// @dev Forwards a swap callback of a Uniswap V3 fork to `uniswapV3SwapCallback` of the helper
  function _forwardUniswapV3SwapCallback() internal {
    bytes memory data = msg.data;
    bytes4 selector = bytes4(keccak256('uniswapV3SwapCallback(int256,int256,bytes)'));
    assembly ('memory-safe') {
      mstore(add(data, 0x20), or(and(mload(add(data, 0x20)), not(MASK_BYTES_4)), selector))
    }

    _forwardCallback(data);
  }
}
