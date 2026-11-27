// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFlashLoanReceiver} from '../flashloan/IFlashLoanReceiver.sol';

import {BoolAddress} from '../../../types/BoolAddress.sol';
import {PackedU128} from '../../../types/PackedU128.sol';

/// @title IZapLeverageAdapter
/// @notice Interface of {ZapLeverageAdapter}
interface IZapLeverageAdapter is IFlashLoanReceiver {
  /// @notice Thrown when the caller is not allowed to call the function
  error UnauthorizedCaller(address caller);

  /// @notice Thrown when {receiveFlashLoan} does not run as a delegatecall of the flash loan
  /// adapter
  error NotFlashLoanAdapter();

  /// @notice Thrown when the loan token is neither the lending token nor its native or wrapped
  /// form
  error LoanTokenMismatch(address loanToken, address lendingToken);

  /// @notice Thrown when the collateral amount supplied is below the minimum
  error LeverageInsufficientCollateralDeposit(
    uint256 collateralAmount, uint256 minCollateralDeposit
  );

  /// @notice Thrown when the debt amount borrowed is above the maximum
  error LeverageExcessiveDebtBorrow(uint256 debtAmount, uint256 maxDebtBorrow);

  /// @notice Thrown when the debt amount repaid is below the minimum
  error LeverageInsufficientDebtRepay(uint256 debtAmount, uint256 minDebtRepay);

  /// @notice Thrown when the collateral amount withdrawn is above the maximum
  error LeverageExcessiveCollateralWithdraw(
    uint256 collateralAmount, uint256 maxCollateralWithdraw
  );

  /// @notice The list of leverage action types
  enum ActionType {
    /// Increases the leverage: supplies the collateral and borrows the debt to repay the flash loan
    INCREASE_LEVERAGE,
    /// Decreases the leverage: repays the debt and withdraws the collateral to repay the flash loan
    DECREASE_LEVERAGE
  }

  /**
   * @notice The parameters of an increase of the leverage
   * @param lendingAdapter The lending adapter delegatecalled for the position change
   * @param lendingContext The encoded lending context
   * @param collateralToken The collateral token supplied, the native token for the native balance
   * @param debtToken The debt token borrowed, the loan token or its native or wrapped form
   * @param minCollateralDeposit The minimum amount of `collateralToken` supplied
   * @param maxDebtBorrow The maximum amount of `debtToken` borrowed
   */
  struct IncreaseLeverageParams {
    address lendingAdapter;
    bytes lendingContext;
    address collateralToken;
    address debtToken;
    uint256 minCollateralDeposit;
    uint256 maxDebtBorrow;
  }

  /**
   * @notice The parameters of a decrease of the leverage
   * @param lendingAdapter The lending adapter delegatecalled for the position change
   * @param lendingContext The encoded lending context
   * @param collateralToken The collateral token withdrawn, the loan token or its native or wrapped
   * form
   * @param debtToken The debt token repaid, the native token for the native balance
   * @param withdrawFull Whether the whole collateral is withdrawn and the whole debt repaid
   * @param minDebtRepay The minimum amount of `debtToken` repaid. With `withdrawFull` the amount is
   * `type(uint256).max`.
   * @param maxCollateralWithdraw The maximum amount of `collateralToken` withdrawn. With
   * `withdrawFull` the amount is `type(uint256).max`, so a full withdrawal needs
   * `type(uint256).max`.
   * @param minSweepAmounts The minimum amounts of `collateralToken` (value0) and `debtToken`
   * (value1) transferred to the owner after the decrease. A balance less 1 wei that is zero or below
   * its minimum stays in the Safe Account.
   */
  struct DecreaseLeverageParams {
    address lendingAdapter;
    bytes lendingContext;
    address collateralToken;
    address debtToken;
    bool withdrawFull;
    uint256 minDebtRepay;
    uint256 maxCollateralWithdraw;
    PackedU128 minSweepAmounts;
  }

  /**
   * @notice The solver data of {receiveFlashLoan} when the loan is swapped; the swap sends its
   * output to the Safe Account
   * @param target The swap target, and whether to approve it for the maximum amount of the loan
   * token; the flag is ignored for the native token
   * @param data The calldata of the swap
   */
  struct LeverageSwap {
    BoolAddress target;
    bytes data;
  }

  /**
   * @notice Changes the position of the Safe Account and transfers `amount` of `loanToken` to the
   * flash loan adapter
   * @dev A Safe Account delegatecalls it from a call of KSSafeAccountHub. A decrease then transfers
   * the balances of the collateral token and the debt token to `owner`, within the minimums of
   * {DecreaseLeverageParams}.
   * @param leverageData `abi.encodePacked(ActionType actionType, bytes actionParams)`, where
   * `actionParams` is `abi.encode(IncreaseLeverageParams)` or `abi.encode(DecreaseLeverageParams)`
   * @param loanToken The token of the flash loan
   * @param amount The amount of `loanToken` that the step transfers to the flash loan adapter
   * @param owner The account that receives the balances left after a decrease
   */
  function modifyLeverage(
    bytes calldata leverageData,
    address loanToken,
    uint256 amount,
    address owner
  ) external;

  /**
   * @notice Transfers the whole balance of each of `tokens` to `recipient`
   * @dev A Safe Account delegatecalls it, so the balances are those of the Safe Account. The caller
   * of the Safe Account must be the holder of the NFT of the Safe Account, which is
   * KSSafeAccountHub while it holds the token.
   * @param tokens The tokens to transfer, with the native address for the native balance
   * @param recipient The account that receives the balances
   */
  function withdrawTokens(address[] calldata tokens, address recipient) external;
}
