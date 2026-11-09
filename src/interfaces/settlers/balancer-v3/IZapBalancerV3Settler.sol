// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapSettler} from '../IZapSettler.sol';

import {PackedBits} from '../../../types/PackedBits.sol';

/// @title IZapBalancerV3Settler
/// @notice Interface of {ZapBalancerV3Settler}
interface IZapBalancerV3Settler is IZapSettler {
  /**
   * @notice Parameters of the zap in
   * @param router The Balancer V3 router, or the composite liquidity router for ERC4626 pools
   * @param pool The pool to add liquidity to
   * @param tokens The tokens to add
   * @param approvalFlags Bit i set approves the router through Permit2 for the maximum amount of
   * the token at index i
   * @param wrapUnderlying Whether each token is wrapped by the ERC4626 pool; a nonempty array
   * selects the composite liquidity router
   * @param minBptAmount The minimum amount of BPT to receive
   * @param recipient The receiver of the BPT
   * @param refundRecipient The receiver of the remaining tokens
   */
  struct ZapInParams {
    address router;
    address pool;
    address[] tokens;
    PackedBits approvalFlags;
    bool[] wrapUnderlying;
    uint256 minBptAmount;
    address recipient;
    address refundRecipient;
  }

  /**
   * @notice Result of the zap in
   * @param pool The pool that received the liquidity
   * @param recipient The receiver of the BPT
   * @param remainingAmounts The amounts of the tokens transferred to the refund recipient
   * @param bptAmount The amount of BPT received
   */
  struct ZapInResult {
    address pool;
    address recipient;
    uint256[] remainingAmounts;
    uint256 bptAmount;
  }
}
