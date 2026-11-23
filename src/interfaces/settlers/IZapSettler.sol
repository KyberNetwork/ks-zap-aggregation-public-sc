// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapExecutor} from '../IKSZapExecutor.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';

/// @title IZapSettler
/// @notice Interface every settler implements to be an executor of KSZapRouterV3, which
/// delegatecalls {IKSZapExecutor-executeZap}, and a callee of the allowance hub, which calls
/// {IAHV2Callee-execute}
interface IZapSettler is IKSZapExecutor, IAHV2Callee {
  /// @notice Emitted when liquidity is added
  /// @param zapInLogData ABI-encoded log data specific to the settler
  event ZapIn(bytes zapInLogData);
}
