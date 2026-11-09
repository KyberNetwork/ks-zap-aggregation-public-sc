// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapSettler} from '../IZapSettler.sol';

import {PackedBits} from '../../../types/PackedBits.sol';

/// @title IZapBalancerV2Settler
/// @notice Interface of {ZapBalancerV2Settler}
interface IZapBalancerV2Settler is IZapSettler {
  /**
   * @notice Parameters of the zap in
   * @param vault The Balancer V2 vault
   * @param poolId The id of the pool
   * @param approvalFlags Bit i set approves the vault for the maximum amount of the pool token at
   * index i
   * @param minBptAmount The minimum amount of BPT to mint, enforced by the pool join
   * @param recipient The receiver of the BPT
   * @param refundRecipient The receiver of the remaining tokens
   */
  struct ZapInParams {
    address vault;
    bytes32 poolId;
    PackedBits approvalFlags;
    uint256 minBptAmount;
    address recipient;
    address refundRecipient;
  }

  /**
   * @notice Result of the zap in
   * @param vault The Balancer V2 vault
   * @param poolId The id of the pool
   * @param recipient The receiver of the BPT
   * @param bptAmount The amount of BPT received
   * @param remainingAmounts The amounts of the pool tokens transferred to the refund recipient
   */
  struct ZapInResult {
    address vault;
    bytes32 poolId;
    address recipient;
    uint256 bptAmount;
    uint256[] remainingAmounts;
  }
}
