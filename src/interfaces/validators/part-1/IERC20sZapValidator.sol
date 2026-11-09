// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20sZapValidator {
  error ZapInERC20sInsufficientAmount();

  /**
   * @notice The input for validating ERC20s before zap-in execution
   * @param tokens The tokens to zap in
   * @param recipient The recipient of the tokens
   */
  struct ZapInERC20sBeforeExecutionInput {
    address[] tokens;
    address recipient;
  }

  /**
   * @notice The input for validating ERC20s after zap-in execution
   * @param minAmounts The minimum amounts of tokens to zap in
   */
  struct ZapInERC20sAfterExecutionInput {
    uint256[] minAmounts;
  }
}
