// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapExecutor} from '../IKSZapExecutor.sol';

/// @title IZapSettler
/// @notice Interface every settler implements to be delegatecalled by KSZapRouterV3 as its
/// executor in an owner call of an allowance hub fulfillment
interface IZapSettler is IKSZapExecutor {
  /// @notice Emitted when liquidity is added
  /// @param zapInLogData ABI-encoded log data specific to the settler
  event ZapIn(bytes zapInLogData);
}
