// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';

/// @title IZapAdapter
/// @notice Interface of the zap adapters that AHV2ProxyCallee delegatecalls through
/// {IAHV2Callee-execute}
interface IZapAdapter is IAHV2Callee {
  /// @notice Emitted when liquidity is added
  /// @param zapInLogData ABI-encoded log data specific to the adapter
  event ZapIn(bytes zapInLogData);

  /// @notice Emitted when liquidity is removed
  /// @param removeLogData ABI-encoded log data specific to the adapter
  event RemoveLiquidity(bytes removeLogData);
}
