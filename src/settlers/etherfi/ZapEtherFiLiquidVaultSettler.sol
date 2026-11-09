// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IKSGenericRouter} from '../../interfaces/IKSGenericRouter.sol';
import {
  IZapEtherFiLiquidVaultSettler
} from '../../interfaces/settlers/etherfi/IZapEtherFiLiquidVaultSettler.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {ILiquidRefer} from '../../vendors/etherfi/ILiquidRefer.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {
  ReentrancyGuardTransient
} from 'openzeppelin-contracts/contracts/utils/ReentrancyGuardTransient.sol';

/// @title ZapEtherFiLiquidVaultSettler
/// @notice Deposits the token balance this contract holds into an ether.fi Liquid vault, in an
/// owner call of an allowance hub fulfillment
/// @dev The contract holds no tokens between transactions. 1 wei of the deposited token is
/// retained.
contract ZapEtherFiLiquidVaultSettler is
  IZapEtherFiLiquidVaultSettler,
  ImmutableState,
  ReentrancyGuardTransient
{
  using TokenHelper for address;
  using CommonLibrary for *;

  constructor(address _WETH) ImmutableState(_WETH) {}

  /// @dev Allows the contract to receive native tokens
  receive() external payable {}

  /// @inheritdoc IKSGenericRouter
  function ksExecute(bytes calldata data) external payable nonReentrant returns (bytes memory) {
    ZapInParams calldata params;
    assembly ('memory-safe') {
      params := data.offset
    }

    if (params.assetIn == address(WETH)) {
      WETH.wrapETH();
    }

    params.assetIn.forceApproveInf(params.liquidRefer);
    uint256 amountIn = params.assetIn.selfBalanceMinusOne();

    ZapInResult memory zapInResult;
    zapInResult.teller = params.teller;
    zapInResult.assetOut = params.assetOut;
    zapInResult.recipient = params.recipient;
    zapInResult.assetOutAmount = ILiquidRefer(params.liquidRefer)
      .deposit(params.teller, params.assetIn, amountIn, params.minAssetOut, params.referrer);

    params.assetOut.safeTransfer(params.recipient, zapInResult.assetOutAmount);

    uint256 remainingAmount = params.assetIn.selfBalanceMinusOne();
    if (remainingAmount > 0) {
      params.assetIn.safeTransfer(params.refundRecipient, remainingAmount);
    }

    bytes memory result = abi.encode(zapInResult);
    emit ZapIn(result);

    return result;
  }
}
