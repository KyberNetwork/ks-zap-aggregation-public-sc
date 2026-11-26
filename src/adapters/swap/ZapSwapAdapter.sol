// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IInputScaleHelper} from '../../interfaces/IInputScaleHelper.sol';
import {IZapSwapAdapter} from '../../interfaces/adapters/swap/IZapSwapAdapter.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

/**
 * @title ZapSwapAdapter
 * @notice Swaps the token and native balances of the account that delegatecalls it through a swap
 * target
 */
contract ZapSwapAdapter is IZapSwapAdapter {
  using TokenHelper for address;
  using Address for address;

  /**
   * @inheritdoc IAHV2Callee
   * @dev `ownerData` is ignored. `solverData` is either empty, in which case nothing runs, or
   * `abi.encode(SwapSolverParams)`. A failed swap reverts with the revert data of the swap target,
   * or with {Errors-FailedCall} when there is none. A native swap above the native balance reverts
   * with {Errors-InsufficientBalance}.
   * @return Empty bytes
   */
  function execute(bytes calldata, bytes calldata solverData)
    external
    payable
    returns (bytes memory)
  {
    if (solverData.length == 0) {
      return '';
    }

    SwapSolverParams memory params = abi.decode(solverData, (SwapSolverParams));

    // The balances of all tokens are recorded before any swap runs
    uint256[] memory currentBalances = new uint256[](params.tokens.length);
    for (uint256 i = 0; i < params.tokens.length; i++) {
      currentBalances[i] = params.tokens[i].token.addressValue().selfBalance();
    }

    for (uint256 i = 0; i < params.tokens.length; i++) {
      _swap(params.tokens[i], currentBalances[i], params.swapTarget, params.scaleHelper);
    }

    return '';
  }

  /// @dev Runs the swaps of one token, scaling them from its recorded balance
  function _swap(
    TokenSwapParams memory tokenParams,
    uint256 currentBalance,
    address swapTarget,
    address scaleHelper
  ) internal {
    require(
      tokenParams.expectedAmounts.length == tokenParams.swapData.length, MismatchedArrayLengths()
    );

    address token = tokenParams.token.addressValue();
    bool approvalFlag = tokenParams.token.boolValue();
    // The native token is sent as the value of each swap and is not approved
    bool nativeInput = token.isNative();
    if (approvalFlag && !nativeInput) {
      token.forceApprove(swapTarget, type(uint256).max);
    }

    uint256 expectedBalance = tokenParams.expectedBalance;
    bool canScale = currentBalance < expectedBalance || currentBalance >= tokenParams.minScaleAmount;

    for (uint256 i = 0; i < tokenParams.expectedAmounts.length; i++) {
      uint256 expectedAmount = tokenParams.expectedAmounts[i];

      uint256 scaledAmount;
      if (canScale) {
        ScaleType scaleType = ScaleType(tokenParams.scaleTypes.at(i));
        scaledAmount = _scale(scaleType, currentBalance, expectedBalance, expectedAmount);
      } else {
        scaledAmount = expectedAmount;
      }

      bytes memory scaledData;
      if (scaledAmount != expectedAmount) {
        bool success;
        (success, scaledData) =
          IInputScaleHelper(scaleHelper).getScaledInputData(tokenParams.swapData[i], scaledAmount);
        if (!success) {
          revert ScaleSwapDataFailed();
        }
      } else {
        scaledData = tokenParams.swapData[i];
      }

      // A native input sends the scaled amount as the value of the call; an ERC20 input sends no
      // native value
      if (nativeInput) {
        // forge-lint: disable-next-line(arbitrary-send-eth)
        swapTarget.functionCallWithValue(scaledData, scaledAmount);
      } else {
        swapTarget.functionCall(scaledData);
      }

      currentBalance -= scaledAmount;
      expectedBalance -= expectedAmount;
    }
  }

  /**
   * @dev Returns the input amount of a swap scaled with the ratio of the current to the expected
   * balance as `scaleType` allows, or the expected amount when it does not scale
   * @param scaleType How the input amount is scaled
   * @param currentBalance The current balance of the token
   * @param expectedBalance The balance of the token the swap data is built for
   * @param expectedAmount The input amount the swap data is built for
   * @return scaledAmount The input amount of the swap
   */
  function _scale(
    ScaleType scaleType,
    uint256 currentBalance,
    uint256 expectedBalance,
    uint256 expectedAmount
  ) internal pure returns (uint256 scaledAmount) {
    if (
      scaleType == ScaleType.SCALE_BOTH
        || (currentBalance < expectedBalance && scaleType == ScaleType.SCALE_DOWN_ONLY)
    ) {
      scaledAmount = currentBalance * expectedAmount / expectedBalance;
    } else {
      scaledAmount = expectedAmount;
    }
  }
}
