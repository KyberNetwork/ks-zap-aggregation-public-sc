// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingActionAdapter} from '../../interfaces/modules/lending/ILendingActionAdapter.sol';
import {
  ILeverageFluidZapValidator
} from '../../interfaces/validators/part-1/ILeverageFluidZapValidator.sol';

import {IFluidVaultResolver} from '../../vendors/fluid/IFluidVaultResolver.sol';
import {BalanceDelta} from '../../vendors/uniswap-v4/BalanceDelta.sol';
import {SafeCast} from '../../vendors/uniswap-v4/SafeCast.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';

import {IERC721Enumerable} from 'openzeppelin-contracts/contracts/interfaces/IERC721Enumerable.sol';

contract LeverageFluidZapValidator is ILeverageFluidZapValidator {
  using CalldataDecoder for bytes;
  using SafeCast for uint256;

  function _beforeExecutionZapLeverageFluid(bytes calldata _beforeExecutionInput)
    internal
    view
    returns (bytes memory)
  {
    ZapLeverageFluidBeforeExecutionInput calldata beforeExecutionInput;
    assembly ('memory-safe') {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    address factory = IFluidVaultResolver(beforeExecutionInput.resolver).FACTORY();

    if (beforeExecutionInput.nftId == 0) {
      // validate the first newly minted position
      return abi.encode(0, 0, IERC721Enumerable(factory).totalSupply() + 1);
    }

    (IFluidVaultResolver.UserPosition memory userPosition,) =
      IFluidVaultResolver(beforeExecutionInput.resolver).positionByNftId(beforeExecutionInput.nftId);

    return abi.encode(userPosition.supply, userPosition.borrow, beforeExecutionInput.nftId);
  }

  function _afterExecutionZapLeverageFluid(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {
    ZapLeverageFluidBeforeExecutionInput calldata beforeExecutionInput;
    assembly ('memory-safe') {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    ZapLeverageFluidAfterExecutionInput calldata afterExecutionInput;
    assembly ('memory-safe') {
      afterExecutionInput := _afterExecutionInput.offset
    }

    uint256 initialCollateralAmount = _beforeExecutionOutput.decodeUint256();
    uint256 initialDebtAmount = _beforeExecutionOutput.decodeUint256(1);
    uint256 nftId = _beforeExecutionOutput.decodeUint256(2);

    (
      IFluidVaultResolver.UserPosition memory userPosition,
      IFluidVaultResolver.VaultEntireData memory vaultEntireData
    ) = IFluidVaultResolver(beforeExecutionInput.resolver).positionByNftId(nftId);

    require(
      userPosition.owner == beforeExecutionInput.recipient, ZapLeverageFluidInvalidPositionOwner()
    );
    require(vaultEntireData.vault == beforeExecutionInput.vault, ZapLeverageFluidInvalidVault());

    if (!_checkDeltaInRangeFluid(
        initialCollateralAmount, userPosition.supply, afterExecutionInput.collateralDeltaRange
      )) {
      revert ZapLeverageFluidInvalidCollateralDelta();
    }

    if (!_checkDeltaInRangeFluid(
        initialDebtAmount, userPosition.borrow, afterExecutionInput.debtDeltaRange
      )) {
      revert ZapLeverageFluidInvalidDebtDelta();
    }
  }

  function _checkDeltaInRangeFluid(uint256 initial, uint256 current, BalanceDelta deltaRange)
    internal
    pure
    returns (bool)
  {
    int256 delta = current.toInt256() - initial.toInt256();
    return deltaRange.amount0() <= delta && delta <= deltaRange.amount1();
  }
}
