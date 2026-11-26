// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MASK_BYTES_4} from '../libraries/BitMask.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

/**
 * @notice Returns the target registered for `selector` in the transient callback registry
 * @param selector The selector of the callback
 * @return target The registered target, or the zero address when none is registered
 */
function loadCallback(bytes4 selector) view returns (address target) {
  assembly ('memory-safe') {
    mstore(0, selector)
    target := tload(keccak256(0, 0x20))
  }
}

/// @title CallbackDispatcher
/// @notice Delegatecalls the callbacks that reach the adapter to the targets registered for their
/// selectors in the transient callback registry
/// @dev The contract declares no fallback. An inheriting contract that receives callbacks declares
/// its own fallback and calls `_fallback` from it.
abstract contract CallbackDispatcher {
  /// @notice Thrown when a call is dispatched with a selector that has no registered target while
  /// no target of `uniswapV3SwapCallback` is registered
  /// @param selector The selector of the call
  error CallbackNotRegistered(bytes4 selector);

  /// @dev Selector of the Uniswap V3 swap callback
  bytes4 private constant UNISWAP_V3_SWAP_CALLBACK =
    bytes4(keccak256('uniswapV3SwapCallback(int256,int256,bytes)'));

  /**
   * @dev Registers `target` for `selector` in the transient callback registry while the function
   * runs, and then restores the target registered before it
   * @param selector The selector of the callback
   * @param target The target that the callback is delegatecalled to
   */
  modifier withCallback(bytes4 selector, address target) {
    bytes32 registrySlot;
    address previousTarget;
    assembly ('memory-safe') {
      mstore(0, selector)
      registrySlot := keccak256(0, 0x20)
      previousTarget := tload(registrySlot)
      tstore(registrySlot, target)
    }
    _;
    assembly ('memory-safe') {
      tstore(registrySlot, previousTarget)
    }
  }

  /**
   * @notice Delegatecalls the call to the target registered for its selector and returns the
   * return data of the target
   * @dev A selector without a registered target is delegatecalled as `uniswapV3SwapCallback` when
   * that callback has a registered target, for the pools that rename the Uniswap V3 swap callback.
   * The revert data of the target is bubbled up.
   * @param data The calldata
   * @return The return data of the target
   */
  function _fallback(bytes calldata data) internal returns (bytes memory) {
    address target = loadCallback(msg.sig);
    bytes memory callData = data;

    if (target == address(0)) {
      // A renamed Uniswap V3 swap callback has the same parameters and is rewritten to it
      target = loadCallback(UNISWAP_V3_SWAP_CALLBACK);
      if (target == address(0)) {
        revert CallbackNotRegistered(msg.sig);
      }

      bytes4 selector = UNISWAP_V3_SWAP_CALLBACK;
      assembly ('memory-safe') {
        mstore(
          add(callData, 0x20),
          or(and(mload(add(callData, 0x20)), not(MASK_BYTES_4)), selector)
        )
      }
    }

    // A target without code reverts with `AddressEmptyCode(target)`
    return Address.functionDelegateCall(target, callData);
  }
}
