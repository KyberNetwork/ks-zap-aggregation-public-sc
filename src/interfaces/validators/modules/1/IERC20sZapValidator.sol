// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20sZapValidator {
  error ZapInERC20sInsufficientAmount();

  struct ZapInERC20sBeforeExecutionInput {
    address[] tokens;
    address recipient;
  }

  struct ZapInERC20sAfterExecutionInput {
    uint256[] minAmounts;
  }
}
