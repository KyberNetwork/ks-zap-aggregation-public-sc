// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapAdapter} from '../IZapAdapter.sol';

/// @title IZapEtherFiLiquidVaultAdapter
/// @notice Interface of {ZapEtherFiLiquidVaultAdapter}
interface IZapEtherFiLiquidVaultAdapter is IZapAdapter {
  /// @notice Thrown when the zap in mints no `assetOut` or less than `minAssetOut`
  error ZapInEtherFiLiquidVaultInsufficientAssetOut();

  /// @notice Thrown when the owner data selects the removal of liquidity, which the adapter does
  /// not support
  error RemoveEtherFiLiquidVaultUnsupported();

  /**
   * @notice Parameters of the zap in
   * @param liquidRefer The LiquidRefer deposit router
   * @param teller The teller of the vault
   * @param assetIn The token deposited
   * @param assetOut The vault share token minted
   * @param minAssetOut The minimum amount of vault shares to mint
   * @param referrer The referrer credited for the deposit
   * @param recipient The receiver of the vault shares
   */
  struct ZapInOwnerParams {
    address liquidRefer;
    address teller;
    address assetIn;
    address assetOut;
    uint256 minAssetOut;
    address referrer;
    address recipient;
  }

  /**
   * @notice Result of the zap in
   * @param teller The teller of the vault
   * @param assetOut The vault share token minted
   * @param assetOutAmount The amount of shares minted and sent to `recipient`
   * @param recipient The receiver of the vault shares
   */
  struct ZapInResult {
    address teller;
    address assetOut;
    uint256 assetOutAmount;
    address recipient;
  }
}
