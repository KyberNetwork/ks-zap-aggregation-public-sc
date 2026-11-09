// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapAgainHelperCaller} from '../interfaces/settlers/IZapAgainHelperCaller.sol';
import {IZapPoolSwapHelper} from '../interfaces/settlers/IZapPoolSwapHelper.sol';
import {MASK_BYTES_4} from '../libraries/BitMask.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {TransientSlot} from 'openzeppelin-contracts/contracts/utils/TransientSlot.sol';

/// @title ZapAgainHelperCaller
/// @notice Runs the pool swap of a zap again through a helper and forwards the callbacks of that
/// swap to the helper
/// @dev The helper runs in the context of this contract with its balances and is chosen by the
/// caller of `ksExecute`.
abstract contract ZapAgainHelperCaller is IZapAgainHelperCaller {
  using TransientSlot for *;

  /// @dev Transient slot holding the helper of the ongoing pool swap
  bytes32 private constant ZAP_AGAIN_HELPER_SLOT =
    bytes32(uint256(keccak256('ks.zap.settler.zap-again-helper')) - 1);

  /// @dev Delegatecalls `poolSwap` of the helper and returns its ABI-encoded result
  function _poolSwap(address helper, bytes memory fixedParams, bytes memory variableParams)
    internal
    returns (bytes memory result)
  {
    ZAP_AGAIN_HELPER_SLOT.asAddress().tstore(helper);
    bytes memory returnData = Address.functionDelegateCall(
      helper, abi.encodeCall(IZapPoolSwapHelper.poolSwap, (fixedParams, variableParams))
    );
    ZAP_AGAIN_HELPER_SLOT.asAddress().tstore(address(0));

    return abi.decode(returnData, (bytes));
  }

  /// @dev Delegatecalls the helper of the ongoing pool swap with `data` and returns the raw return
  /// data to the caller of this contract
  function _forwardCallback(bytes memory data) internal {
    address helper = ZAP_AGAIN_HELPER_SLOT.asAddress().tload();
    require(helper != address(0), ZapAgainCallbackNotExpected(msg.sender));

    bytes memory returnData = Address.functionDelegateCall(helper, data);
    assembly ('memory-safe') {
      return(add(returnData, 0x20), mload(returnData))
    }
  }

  /// @dev Forwards a swap callback of a Uniswap V3 fork to `uniswapV3SwapCallback` of the helper
  function _forwardSwapCallback() internal {
    bytes memory data = msg.data;
    bytes4 selector = bytes4(keccak256('uniswapV3SwapCallback(int256,int256,bytes)'));
    assembly ('memory-safe') {
      mstore(add(data, 0x20), or(and(mload(add(data, 0x20)), not(MASK_BYTES_4)), selector))
    }

    _forwardCallback(data);
  }
}
