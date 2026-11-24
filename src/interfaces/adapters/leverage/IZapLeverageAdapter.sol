// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFlashLoanAdapter} from '../../adapters/flashloan/IFlashLoanAdapter.sol';
import {IFlashLoanReceiver} from '../../adapters/flashloan/IFlashLoanReceiver.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';

/// @title IZapLeverageAdapter
/// @notice Interface of {ZapLeverageAdapter}
interface IZapLeverageAdapter is IAHV2Callee, IFlashLoanReceiver {
  /// @notice Thrown when the caller is not allowed to call the function
  error UnauthorizedCaller(address caller);

  /// @notice Thrown when a swap runs and the solver data is empty
  error LeverageSwapMissing();

  /// @notice Thrown when a swap runs with a zero minimum output
  error LeverageSwapUnbounded();

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
   * @notice The parameters the Safe reads in the flash loan callback
   * @param actionType The action type
   * @param wrapOrUnwrap Whether the callback converts between the native token and WETH
   * @param withdrawFull Whether a decrease withdraws the whole collateral and repays the whole debt
   * @param lendingAdapter The lending adapter delegatecalled for the position change
   * @param lendingContext The encoded lending context
   * @param collateralToken The collateral token of the position
   * @param debtToken The debt token of the position
   * @param minCollateralDeposit The minimum collateral amount supplied on an increase
   * @param maxDebtBorrow The maximum debt amount borrowed on an increase
   * @param minDebtRepay The minimum debt amount repaid on a decrease
   * @param maxCollateralWithdraw The maximum collateral amount withdrawn on a decrease
   */
  struct LeverageCallbackParams {
    ActionType actionType;
    bool wrapOrUnwrap;
    bool withdrawFull;
    address lendingAdapter;
    bytes lendingContext;
    address collateralToken;
    address debtToken;
    uint256 minCollateralDeposit;
    uint256 maxDebtBorrow;
    uint256 minDebtRepay;
    uint256 maxCollateralWithdraw;
  }

  /**
   * @notice Parameters of the leverage action
   * @param safe The Safe account of the position
   * @param recipient The receiver of the Safe NFT
   * @param flashLoanSource The source of the flash loan
   * @param flashLoanParams The parameters of the flash loan, specific to the source
   * @param actionType The bounded action type
   * @param wrapOrUnwrap Whether the leverage adapter converts between the native token and WETH
   * @param withdrawFull Whether a decrease withdraws the whole collateral and repays the whole debt
   * @param lendingAdapter The lending adapter of the position
   * @param lendingContext The encoded lending context
   * @param collateralToken The collateral token of the position
   * @param debtToken The debt token of the position
   * @param swapTarget The swap target, the zero address for no swap
   * @param swapApproveMax Whether the flash loan adapter approves the swap target for the maximum
   * amount and keeps the approval, instead of approving `swapAmountIn` and resetting it
   * @param swapTokenOut The token the swap outputs
   * @param swapAmountIn The amount of the flash loaned token the swap spends, zero for no swap
   * @param minSwapAmountOut The minimum increase of the Safe balance of `swapTokenOut`
   * @param minCollateralDeposit The minimum collateral amount supplied on an increase, compared
   * with the amount passed to the lending adapter after the wrap or unwrap relabeling and the
   * scaling of the Arc native token
   * @param maxDebtBorrow The maximum debt amount borrowed on an increase, compared as
   * `minCollateralDeposit` is
   * @param minDebtRepay The minimum debt amount repaid on a decrease, compared as
   * `minCollateralDeposit` is. With `withdrawFull` the amount is `type(uint256).max`.
   * @param maxCollateralWithdraw The maximum collateral amount withdrawn on a decrease, compared as
   * `minCollateralDeposit` is. With `withdrawFull` the amount is `type(uint256).max`, so a full
   * withdrawal needs `type(uint256).max`.
   */
  struct LeverageParams {
    address safe;
    address recipient;
    IFlashLoanAdapter.FlashLoanSource flashLoanSource;
    bytes flashLoanParams;
    ActionType actionType;
    bool wrapOrUnwrap;
    bool withdrawFull;
    address lendingAdapter;
    bytes lendingContext;
    address collateralToken;
    address debtToken;
    address swapTarget;
    bool swapApproveMax;
    address swapTokenOut;
    uint256 swapAmountIn;
    uint256 minSwapAmountOut;
    uint256 minCollateralDeposit;
    uint256 maxDebtBorrow;
    uint256 minDebtRepay;
    uint256 maxCollateralWithdraw;
  }

  /// @notice Returns the allowance hub, the only account allowed to call {execute}
  function ALLOWANCE_HUB() external view returns (address);

  /// @notice Returns the KSSafeAccountHub that holds the Safe NFT during {execute}
  function SAFE_ACCOUNT_HUB() external view returns (address);

  /// @notice Returns the flash loan adapter, the only account allowed to call
  /// {receiveFlashLoan}
  function FLASH_LOAN_ADAPTER() external view returns (address);

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
