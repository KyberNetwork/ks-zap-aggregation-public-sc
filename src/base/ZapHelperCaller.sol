// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IZapHelper} from '../interfaces/adapters/IZapHelper.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

/// @title ZapHelperCaller
/// @notice Delegatecalls the pool swap of a zap helper
/// @dev The helper runs in the context of this contract, with its balances. The callbacks of the
/// pool swap go through the callback registry of {CallbackDispatcher}.
abstract contract ZapHelperCaller {
  /// @dev Delegatecalls `poolSwap` of `helper` with the owner, solver and additional data and
  /// returns its result. Reverts when `helper` has no code.
  function _poolSwap(
    address helper,
    bytes calldata ownerData,
    bytes calldata solverData,
    bytes memory additionalData
  ) internal returns (bytes memory) {
    bytes memory data = abi.encodeCall(IZapHelper.poolSwap, (ownerData, solverData, additionalData));

    return Address.functionDelegateCall(helper, data);
  }
}
