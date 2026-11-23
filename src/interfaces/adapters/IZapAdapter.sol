// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapExecutor} from '../IKSZapExecutor.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';

/// @title IZapAdapter
/// @notice Interface every adapter implements to be an executor of KSZapRouterV3, which
/// delegatecalls {IKSZapExecutor-executeZap}, and a callee of the allowance hub, which calls
/// {IAHV2Callee-execute}
interface IZapAdapter is IKSZapExecutor, IAHV2Callee {
  /// @notice Emitted when liquidity is added
  /// @param zapInLogData ABI-encoded log data specific to the adapter
  event ZapIn(bytes zapInLogData);
}
