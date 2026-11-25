// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapExecutor} from '../../IKSZapExecutor.sol';
import {IZapAdapter} from '../IZapAdapter.sol';
import {IZapPancakeInfinityBaseHelperTypes} from './IZapPancakeInfinityBaseHelperTypes.sol';

import {PoolKey} from '../../../vendors/pancake-infinity/PoolKey.sol';

import {PackedBits} from '../../../types/PackedBits.sol';

/// @title IZapPancakeInfinityBaseAdapter
/// @notice Interface of {ZapPancakeInfinityBaseAdapter}
interface IZapPancakeInfinityBaseAdapter is
  IZapAdapter,
  IKSZapExecutor,
  IZapPancakeInfinityBaseHelperTypes
{
  /// @notice Thrown when the added liquidity is below the minimum
  error ZapInPancakeInfinityInsufficientLiquidity();

  /**
   * @notice Parameters of the zap in
   * @param posManager The position manager
   * @param vault The vault of the pool
   * @param poolKey The pool key; its pool manager is the CL pool manager
   * @param tickLower The lower tick of the position
   * @param tickUpper The upper tick of the position
   * @param tokenId The position to add liquidity to, 0 mints a new position; an existing position
   * must be held by this contract
   * @param addLiquidityHookData The data for the add liquidity hook
   * @param readBalanceFlag Whether to settle the amounts to the vault before adding and read the
   * resulting deltas and balances, for fee-on-transfer tokens
   * @param approvalFlags Bit 0 and bit 1 set approve Permit2 for the maximum amount of currency0
   * and currency1 and approve the position manager on Permit2
   * @param minLiquidity The minimum liquidity to add
   * @param recipient The receiver of the position
   * @param refundRecipient The receiver of the remaining tokens
   * @param helper The helper delegatecalled for the pool swap of the zap again; the zero address
   * disables the zap again
   */
  struct ZapInParams {
    address posManager;
    address vault;
    PoolKey poolKey;
    int24 tickLower;
    int24 tickUpper;
    uint256 tokenId;
    bytes addLiquidityHookData;
    bool readBalanceFlag;
    PackedBits approvalFlags;
    uint128 minLiquidity;
    address recipient;
    address refundRecipient;
    address helper;
  }

  /**
   * @notice Result of the zap in
   * @param posManager The position manager
   * @param tokenId The position that received the liquidity
   * @param recipient The receiver of the position
   * @param originalAmount0 The amount of currency0 held before adding liquidity
   * @param originalAmount1 The amount of currency1 held before adding liquidity
   * @param positionLiquidity The liquidity added
   * @param addedAmount0 The amount of currency0 added
   * @param addedAmount1 The amount of currency1 added
   * @param remainingAmount0 The amount of currency0 transferred to the refund recipient
   * @param remainingAmount1 The amount of currency1 transferred to the refund recipient
   */
  struct ZapInResult {
    address posManager;
    uint256 tokenId;
    address recipient;
    uint256 originalAmount0;
    uint256 originalAmount1;
    uint128 positionLiquidity;
    uint256 addedAmount0;
    uint256 addedAmount1;
    uint256 remainingAmount0;
    uint256 remainingAmount1;
  }

  /**
   * @notice Adds liquidity inside the vault lock of the zap in
   * @param data ABI-encoded zap in parameters
   * @return result ABI-encoded zap in result
   */
  function lockAcquired(bytes calldata data) external returns (bytes memory result);
}
