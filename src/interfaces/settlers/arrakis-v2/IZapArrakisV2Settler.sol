// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapSettler} from '../IZapSettler.sol';
import {IZapArrakisV2HelperTypes} from './IZapArrakisV2HelperTypes.sol';

import {PackedBits} from '../../../types/PackedBits.sol';
import {PackedU128} from '../../../types/PackedU128.sol';

/// @title IZapArrakisV2Settler
/// @notice Interface of {ZapArrakisV2Settler}
interface IZapArrakisV2Settler is IZapSettler, IZapArrakisV2HelperTypes {
  /// @notice Thrown when the shares minted are below the minimum
  error ZapArrakisV2InsufficientShares();

  /**
   * @notice Parameters of the swap and the second deposit with the remaining tokens
   * @param helper The helper delegatecalled for the pool swap of the zap again; the zero address
   * disables the zap again
   * @param minZapInAmounts The remaining amounts of token0 and token1 from which the zap again runs;
   * it runs when either remaining amount is at least its minimum
   * @param sqrtPriceLimit0X96 The lower sqrt price limit of the swap preview
   * @param sqrtPriceLimit1X96 The upper sqrt price limit of the swap preview
   * @param iterations The number of binary search iterations of the swap preview
   */
  struct ZapAgainParams {
    address helper;
    PackedU128 minZapInAmounts;
    uint160 sqrtPriceLimit0X96;
    uint160 sqrtPriceLimit1X96;
    uint256 iterations;
  }

  /**
   * @notice Parameters of the zap in
   * @param vault The vault to deposit into
   * @param pool The pool of the vault
   * @param router The Arrakis V2 router or the Gamma UniProxy; unused by Steer
   * @param gauge The Arrakis V2 gauge; unused by Steer and Gamma
   * @param approvalFlags Bit 0 and bit 1 set approve the approval target for the maximum amount of
   * token0 and token1; the target is the router for Arrakis V2 and the vault for Steer and Gamma
   * @param minShares The minimum shares to mint
   * @param recipient The receiver of the shares
   * @param refundRecipient The receiver of the remaining tokens
   * @param zapAgain Parameters of the zap again
   */
  struct ZapInParams {
    address vault;
    address pool;
    address router;
    address gauge;
    PackedBits approvalFlags;
    uint128 minShares;
    address recipient;
    address refundRecipient;
    ZapAgainParams zapAgain;
  }

  /**
   * @notice Result of the zap in
   * @param vault The vault that minted the shares
   * @param recipient The receiver of the shares
   * @param originalAmount0 The amount of token0 held before depositing
   * @param originalAmount1 The amount of token1 held before depositing
   * @param shares The shares minted
   * @param addedAmount0 The amount of token0 deposited
   * @param addedAmount1 The amount of token1 deposited
   * @param remainingAmount0 The amount of token0 transferred to the refund recipient
   * @param remainingAmount1 The amount of token1 transferred to the refund recipient
   */
  struct ZapInResult {
    address vault;
    address recipient;
    uint256 originalAmount0;
    uint256 originalAmount1;
    uint256 shares;
    uint256 addedAmount0;
    uint256 addedAmount1;
    uint256 remainingAmount0;
    uint256 remainingAmount1;
  }
}
