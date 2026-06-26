// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanAdapter {
  /// @notice Thrown when the execution fails
  error SafeModuleExecutionFailed(bytes reason);

  /// @notice Thrown when the flash loan source is invalid
  error InvalidFlashLoanSource(FlashLoanSource source);

  /// @notice The list of flash loan sources
  enum FlashLoanSource {
    AAVE_V3,
    BALANCER_V2,
    BALANCER_V3,
    ERC3156,
    MORPHO_BLUE,
    UNISWAP_V3,
    UNISWAP_V4,
    PANCAKE_INFINITY,
    EULER_V2
  }

  enum ReceiverType {
    NORMAL,
    SAFE_ACCOUNT
  }

  function flashLoan(uint256 flashLoanContext, bytes calldata flashLoanParams, bytes calldata data)
    external
    payable;
}
