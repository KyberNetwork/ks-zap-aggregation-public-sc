// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20sZapValidator {
  error ZapIn__ERC20s__InsufficientAmount();

  struct ZapIn__ERC20s_BeforeExecutionInput {
    address[] tokens;
    address recipient;
  }

  struct ZapIn__ERC20s_AfterExecutionInput {
    uint256[] minAmounts;
  }
}
