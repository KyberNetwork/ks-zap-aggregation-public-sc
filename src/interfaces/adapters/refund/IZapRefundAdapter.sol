// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {ICommon} from 'ks-common-sc/src/interfaces/ICommon.sol';

/// @title IZapRefundAdapter
/// @notice Interface of {ZapRefundAdapter}
interface IZapRefundAdapter is IAHV2Callee, ICommon {
  /**
   * @notice Emitted when a balance is transferred to the recipient
   * @param token The token transferred, the native token for the native balance
   * @param recipient The recipient of the refund
   * @param amount The amount transferred
   */
  event Refund(address indexed token, address indexed recipient, uint256 amount);

  /**
   * @notice Parameters of the refund, signed by the owner
   * @param recipient The recipient of the balances; the zero address is refused with
   * {ICommon-InvalidAddress}
   * @param tokens The tokens to refund, the native token for the native balance
   * @param minAmounts The minimum amount of each token; a smaller amount is not transferred
   */
  struct RefundOwnerParams {
    address recipient;
    address[] tokens;
    uint256[] minAmounts;
  }
}
