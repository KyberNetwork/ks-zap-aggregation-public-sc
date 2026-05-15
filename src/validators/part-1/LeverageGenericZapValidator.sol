// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingActionAdapter} from '../../interfaces/modules/lending/ILendingActionAdapter.sol';
import {
  ILeverageGenericZapValidator
} from '../../interfaces/validators/part-1/ILeverageGenericZapValidator.sol';
import {BalanceDelta} from '../../vendors/uniswap-v4/BalanceDelta.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';

contract LeverageGenericZapValidator is ILeverageGenericZapValidator {
  using CalldataDecoder for bytes;

  function _beforeExecutionZapLeverageGeneric(bytes calldata _beforeExecutionInput)
    internal
    returns (bytes memory)
  {
    ZapLeverageGenericBeforeExecutionInput calldata beforeExecutionInput;
    assembly ('memory-safe') {
      beforeExecutionInput := add(
        _beforeExecutionInput.offset,
        calldataload(_beforeExecutionInput.offset)
      )
    }

    (uint256 initialCollateralAmount, uint256 initialDebtAmount) = ILendingActionAdapter(
        beforeExecutionInput.lendingAdapter
      )
      .getPosition(
        beforeExecutionInput.lendingContext,
        beforeExecutionInput.collateralToken,
        beforeExecutionInput.debtToken,
        beforeExecutionInput.recipient
      );

    return abi.encode(initialCollateralAmount, initialDebtAmount);
  }

  function _afterExecutionZapLeverageGeneric(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal {
    ZapLeverageGenericBeforeExecutionInput calldata beforeExecutionInput;
    assembly ('memory-safe') {
      beforeExecutionInput := add(
        _beforeExecutionInput.offset,
        calldataload(_beforeExecutionInput.offset)
      )
    }

    ZapLeverageGenericAfterExecutionInput calldata afterExecutionInput;
    assembly ('memory-safe') {
      afterExecutionInput := _afterExecutionInput.offset
    }

    uint256 initialCollateralAmount = _beforeExecutionOutput.decodeUint256();
    uint256 initialDebtAmount = _beforeExecutionOutput.decodeUint256(1);

    (uint256 currentCollateralAmount, uint256 currentDebtAmount) = ILendingActionAdapter(
        beforeExecutionInput.lendingAdapter
      )
      .getPosition(
        beforeExecutionInput.lendingContext,
        beforeExecutionInput.collateralToken,
        beforeExecutionInput.debtToken,
        beforeExecutionInput.recipient
      );

    if (!_checkDeltaInRangeGeneric(
        initialCollateralAmount, currentCollateralAmount, afterExecutionInput.collateralDeltaRange
      )) {
      revert ZapLeverageGenericInvalidCollateralDelta();
    }

    if (!_checkDeltaInRangeGeneric(
        initialDebtAmount, currentDebtAmount, afterExecutionInput.debtDeltaRange
      )) {
      revert ZapLeverageGenericInvalidDebtDelta();
    }
  }

  function _checkDeltaInRangeGeneric(uint256 initial, uint256 current, BalanceDelta deltaRange)
    internal
    pure
    returns (bool)
  {
    int256 delta = int256(current) - int256(initial);

    return int128(deltaRange.amount0()) <= delta && delta <= int128(deltaRange.amount1());
  }
}
