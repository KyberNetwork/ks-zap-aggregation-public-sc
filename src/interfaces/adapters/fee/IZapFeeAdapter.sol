// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {ICommon} from 'ks-common-sc/src/interfaces/ICommon.sol';

/// @title IZapFeeAdapter
/// @notice Interface of {ZapFeeAdapter}
interface IZapFeeAdapter is IAHV2Callee, ICommon {
  /**
   * @notice Thrown when a fee exceeds the maximum that the owner allows for its recipient
   * @param token The token the fee is taken in
   * @param recipient The recipient of the fee
   * @param amount The fee amount
   * @param maxAmount The maximum fee amount for the recipient
   */
  error FeeExceedsCap(address token, address recipient, uint256 amount, uint256 maxAmount);

  /**
   * @notice Emitted when a fee is transferred to a recipient
   * @param token The token the fee is taken in
   * @param recipient The recipient of the fee
   * @param baseAmount The balance of `token` the fee is computed from
   * @param amount The fee amount
   */
  event TakeFee(
    address indexed token, address indexed recipient, uint256 baseAmount, uint256 amount
  );

  /**
   * @notice The maximum fee rate of a recipient
   * @param recipient The recipient of the fee
   * @param maxFeeRate The maximum fee rate, out of `FEE_DENOMINATOR`
   */
  struct FeeCap {
    address recipient;
    uint256 maxFeeRate;
  }

  /**
   * @notice The fee caps of a token
   * @param token The token the fees are taken in, the native token for the native balance
   * @param caps The fee caps of the recipients
   */
  struct TokenFeeCaps {
    address token;
    FeeCap[] caps;
  }

  /**
   * @notice The denominator of the fee rates
   * @return The denominator of the fee rates
   */
  function FEE_DENOMINATOR() external view returns (uint256);

  /**
   * @notice The flag that marks a solver fee value as a flat amount
   * @return The bit that is set in a fee value to mark it as a flat amount
   */
  function FLAT_FEE_FLAG() external view returns (uint256);
}
