// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IZapRefundAdapter} from '../../interfaces/adapters/refund/IZapRefundAdapter.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/**
 * @title ZapRefundAdapter
 * @notice Transfers the token balances of the account that delegatecalls it, less 1 wei of each, to
 * a recipient
 */
contract ZapRefundAdapter is IZapRefundAdapter {
  using TokenHelper for address;
  using CommonLibrary for address;

  /**
   * @inheritdoc IAHV2Callee
   * @dev `ownerData` is `abi.encode(RefundOwnerParams)`. `solverData` is ignored. A token whose
   * amount is zero or below its minimum is not transferred, and the call does not revert. A zero
   * recipient reverts with {ICommon-InvalidAddress}.
   * @return The amounts transferred, as `abi.encode(uint256[])` with one amount per token
   */
  function execute(bytes calldata ownerData, bytes calldata)
    external
    payable
    returns (bytes memory)
  {
    RefundOwnerParams memory params = abi.decode(ownerData, (RefundOwnerParams));
    require(params.recipient != address(0), InvalidAddress());
    require(params.tokens.length == params.minAmounts.length, MismatchedArrayLengths());

    uint256[] memory amounts = new uint256[](params.tokens.length);
    for (uint256 i = 0; i < params.tokens.length; i++) {
      address token = params.tokens[i];
      // The amount is the balance less 1 wei when the token is reached, so a token listed twice is
      // transferred once
      uint256 amount = token.selfBalanceMinusOne();
      // An amount that is zero or below its minimum stays in the balance
      if (amount != 0 && amount >= params.minAmounts[i]) {
        token.safeTransfer(params.recipient, amount);
        emit Refund(token, params.recipient, amount);
        amounts[i] = amount;
      }
    }

    return abi.encode(amounts);
  }
}
