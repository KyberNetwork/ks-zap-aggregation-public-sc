// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingActionAdapter {
  /// @notice Thrown when supply collateral on behalf user is not supported
  error SupplyCollateralOnBehalfOfNotSupported();

  /// @notice Thrown when withdraw collateral on behalf of user is not supported
  error WithdrawCollateralOnBehalfOfNotSupported();

  /// @notice Thrown when borrow on behalf of user is not supported
  error BorrowOnBehalfOfNotSupported();

  /// @notice Thrown when repay on behalf of user is not supported
  error RepayOnBehalfOfNotSupported();

  /**
   * @notice Get the position of the user
   * @param lendingContext The encoded lending info
   * @param collateralToken The collateral token
   * @param debtToken The debt token
   * @param user The user address
   * @return collateralAmount The collateral amount
   * @return debtAmount The debt amount
   */
  function getPosition(
    bytes calldata lendingContext,
    address collateralToken,
    address debtToken,
    address user
  ) external returns (uint256 collateralAmount, uint256 debtAmount);

  /**
   * @notice Supply collateral to the lending pool
   * @param lendingContext The encoded lending info
   * @param collateralToken The collateral token
   * @param supplyAmount The amount of collateral to supply
   * @param onBehalfOf The address to act on behalf of
   */
  function supplyCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) external payable;

  /**
   * @notice Withdraw collateral from the lending pool
   * @param lendingContext The encoded lending info
   * @param collateralToken The collateral token
   * @param withdrawAmount The amount of collateral to withdraw
   * @param onBehalfOf The address to act on behalf of
   */
  function withdrawCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable;

  /**
   * @notice Borrow debt from the lending pool
   * @param lendingContext The encoded lending info
   * @param debtToken The debt token
   * @param borrowAmount The amount of debt to borrow
   * @param onBehalfOf The address to act on behalf of
   */
  function borrow(
    bytes calldata lendingContext,
    address debtToken,
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable;

  /**
   * @notice Repay debt to the lending pool
   * @param lendingContext The encoded lending info
   * @param debtToken The debt token
   * @param repayAmount The amount of debt to repay
   * @param onBehalfOf The address to act on behalf of
   */
  function repay(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) external payable;

  /**
   * @notice Supply collateral and borrow debt from the lending pool
   * @param lendingContext The encoded lending info
   * @param collateralToken The collateral token
   * @param supplyAmount The amount of collateral to supply
   * @param debtToken The debt token
   * @param borrowAmount The amount of debt to borrow
   * @param onBehalfOf The address to act on behalf of
   */
  function supplyCollateralAndBorrow(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address debtToken,
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable;

  /**
   * @notice Repay debt and withdraw collateral from the lending pool
   * @param lendingContext The encoded lending info
   * @param debtToken The debt token
   * @param repayAmount The amount of debt to repay
   * @param collateralToken The collateral token
   * @param withdrawAmount The amount of collateral to withdraw
   * @param onBehalfOf The address to act on behalf of
   */
  function repayAndWithdrawCollateral(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address collateralToken,
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable;
}
