// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSGenericRouter} from '../IKSGenericRouter.sol';

/// @title IZapSettler
/// @notice Interface every settler implements to be called by the allowance hub in owner calls
interface IZapSettler is IKSGenericRouter {
  /// @notice Emitted when liquidity is added
  /// @param zapInLogData ABI-encoded log data specific to the settler
  event ZapIn(bytes zapInLogData);
}
