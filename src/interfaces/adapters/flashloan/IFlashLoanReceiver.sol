// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanReceiver {
  function receiveFlashLoan(
    address[] calldata tokens,
    uint256[] calldata amounts,
    bytes calldata data
  ) external payable;
}
