// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {ICommon} from 'ks-common-sc/src/interfaces/ICommon.sol';

/// @title IFlashLoanAdapter
/// @notice Interface of {FlashLoanAdapter}
interface IFlashLoanAdapter is IAHV2Callee, ICommon {
  /// @notice Thrown when `execute` is called while a flash loan runs
  error FlashLoanInProgress();

  /// @notice Thrown when a flash loan callback runs while no flash loan waits for its callback
  error UnexpectedFlashLoanCallback();

  /// @notice Thrown when the caller is not the proxy callee
  error UnauthorizedCaller(address caller);

  /// @notice Thrown when a flash loan callback is not called by the callback caller of the flash
  /// loan
  error UnauthorizedCallbackCaller(address caller);

  /// @notice Thrown when the lender did not call back during the flash loan
  error FlashLoanNotCalledBack();

  /// @notice The list of flash loan sources
  enum FlashLoanSource {
    AAVE_V3,
    ERC3156,
    MORPHO_BLUE,
    UNISWAP_V3,
    UNISWAP_V4,
    PANCAKE_INFINITY,
    EULER_V2
  }
}
