// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BoolAddress} from '../../../types/BoolAddress.sol';
import {PackedU8} from '../../../types/PackedU8.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {ICommon} from 'ks-common-sc/src/interfaces/ICommon.sol';

/// @title IZapSwapAdapter
/// @notice Interface of {ZapSwapAdapter}
interface IZapSwapAdapter is IAHV2Callee, ICommon {
  /// @notice Thrown when the scale helper does not scale the swap data
  error ScaleSwapDataFailed();

  /// @notice How the input amount of a swap is scaled to the current balance
  enum ScaleType {
    /// Scales the input amount up or down with the ratio of the current to the expected balance
    SCALE_BOTH,
    /// Scales the input amount down only, when the current balance is below the expected balance
    SCALE_DOWN_ONLY,
    /// Keeps the input amount as given
    FIXED
  }

  /**
   * @notice Parameters of the swaps of one token
   * @param token The token, and whether to approve the swap target for the maximum amount
   * @param minScaleAmount The balance from which the swaps are scaled when it is above the
   * expected balance
   * @param scaleTypes The packed {ScaleType} of each swap
   * @param expectedBalance The balance of the token for which the swap data is built
   * @param expectedAmounts The amount of the token that each swap spends at the expected balance
   * @param swapData The calldata of each swap
   */
  struct TokenSwapParams {
    BoolAddress token;
    uint256 minScaleAmount;
    PackedU8 scaleTypes;
    uint256 expectedBalance;
    uint256[] expectedAmounts;
    bytes[] swapData;
  }

  /**
   * @notice Solver parameters of the adapter
   * @param swapTarget The contract called with each `swapData`
   * @param scaleHelper The {IInputScaleHelper} used to scale the swap data
   * @param tokens The parameters of each token
   */
  struct SwapSolverParams {
    address swapTarget;
    address scaleHelper;
    TokenSwapParams[] tokens;
  }
}
