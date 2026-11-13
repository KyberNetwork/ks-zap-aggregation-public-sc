// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapSettler} from '../IZapSettler.sol';

/// @title IZapEtherFiLiquidVaultSettler
/// @notice Interface of {ZapEtherFiLiquidVaultSettler}
interface IZapEtherFiLiquidVaultSettler is IZapSettler {
  /**
   * @notice Parameters of the zap in
   * @param liquidRefer The LiquidRefer deposit router
   * @param teller The teller of the vault
   * @param assetIn The token deposited
   * @param assetOut The vault share token minted
   * @param minAssetOut The minimum amount of vault shares to mint, enforced by the teller
   * @param referrer The referrer credited for the deposit
   * @param recipient The receiver of the vault shares
   * @param refundRecipient The receiver of the remaining tokens
   */
  struct ZapInParams {
    address liquidRefer;
    address teller;
    address assetIn;
    address assetOut;
    uint256 minAssetOut;
    address referrer;
    address recipient;
    address refundRecipient;
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
