// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IFlashLoanReceiver
/// @notice Interface of the target that {FlashLoanAdapter} delegatecalls while a flash loan is held
interface IFlashLoanReceiver {
  /**
   * @notice Delegatecalled by the flash loan adapter inside the callback of the lender
   * @dev It runs in the context of the flash loan adapter, which holds the loan. When it returns,
   * that context must hold at least `owedAmounts[i]` of `tokens[i]`.
   * @param tokens The tokens of the flash loan
   * @param owedAmounts The amount of each token that the flash loan adapter owes the lender
   * @param ownerData The data of the owner for the target
   * @param solverData The data of the solver for the target
   */
  function receiveFlashLoan(
    address[] calldata tokens,
    uint256[] calldata owedAmounts,
    bytes calldata ownerData,
    bytes calldata solverData
  ) external;
}
