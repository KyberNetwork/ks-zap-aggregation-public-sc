// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {
  IZapEtherFiLiquidVaultAdapter
} from '../../interfaces/adapters/etherfi/IZapEtherFiLiquidVaultAdapter.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {LiquidityAction} from '../../types/LiquidityAction.sol';
import {ILiquidRefer} from '../../vendors/etherfi/ILiquidRefer.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/**
 * @title ZapEtherFiLiquidVaultAdapter
 * @notice Deposits the balance of one token of the account that delegatecalls it into an ether.fi
 * Liquid vault through LiquidRefer
 * @dev AHV2ProxyCallee delegatecalls the adapter, so the balances are those of the proxy. The
 * adapter does not remove liquidity: the vault pays withdrawals through a queue, outside the
 * transaction.
 */
contract ZapEtherFiLiquidVaultAdapter is IZapEtherFiLiquidVaultAdapter, ImmutableState {
  using TokenHelper for address;
  using CommonLibrary for *;

  /// @param _WETH The wrapped native token
  constructor(address _WETH) ImmutableState(_WETH) {}

  /// @dev Accepts native balance
  receive() external payable {}

  /**
   * @inheritdoc IAHV2Callee
   * @dev `ownerData` is
   * `abi.encodePacked(LiquidityAction.ADD_LIQUIDITY, abi.encode(ZapInOwnerParams))` and
   * `solverData` is not read. `REMOVE_LIQUIDITY` reverts with
   * `RemoveEtherFiLiquidVaultUnsupported`, and an invalid action byte reverts with the panic code
   * 0x21.
   */
  function execute(bytes calldata ownerData, bytes calldata)
    external
    payable
    returns (bytes memory)
  {
    LiquidityAction action = LiquidityAction(uint8(ownerData[0]));
    require(action == LiquidityAction.ADD_LIQUIDITY, RemoveEtherFiLiquidVaultUnsupported());

    return _zapIn(ownerData[1:]);
  }

  /// @dev Deposits the balance of the token described by `data` and transfers the vault shares to
  /// the recipient
  function _zapIn(bytes calldata data) internal returns (bytes memory) {
    ZapInOwnerParams calldata params;
    assembly ('memory-safe') {
      params := data.offset
    }

    // A deposit of the wrapped native token includes the native balance, wrapped.
    if (params.assetIn == address(WETH)) {
      WETH.wrapETH();
    }

    uint256 amountIn = params.assetIn.selfBalanceMinusOne();

    ZapInResult memory zapInResult;
    zapInResult.teller = params.teller;
    zapInResult.assetOut = params.assetOut;
    zapInResult.recipient = params.recipient;

    // LiquidRefer pulls the amount, deposits it through the teller with a zero minimum and
    // transfers the minted `assetOut` to the proxy. The adapter checks the amount against
    // `minAssetOut` and transfers it to the recipient.
    params.assetIn.forceApproveInf(params.liquidRefer);
    zapInResult.assetOutAmount = ILiquidRefer(params.liquidRefer)
      .deposit(params.teller, params.assetIn, amountIn, 0, params.referrer);
    require(
      zapInResult.assetOutAmount != 0 && zapInResult.assetOutAmount >= params.minAssetOut,
      ZapInEtherFiLiquidVaultInsufficientAssetOut()
    );
    params.assetOut.safeTransfer(params.recipient, zapInResult.assetOutAmount);

    bytes memory result = abi.encode(zapInResult);
    emit ZapIn(result);

    return result;
  }
}
