// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISolidlyV3ZapValidator} from
  '../../../interfaces/validators/modules/1/ISolidlyV3ZapValidator.sol';

import {ISolidlyV3Pool} from '../../../vendors/solidly-v3/ISolidlyV3Pool.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';

contract SolidlyV3ZapValidator is ISolidlyV3ZapValidator {
  using CalldataDecoder for bytes;

  function _beforeExecutionZapInSolidlyV3(bytes calldata _beforeExecutionInput)
    internal
    view
    returns (bytes memory)
  {
    SolidlyV3BeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    (uint256 initialLiquidity,,) =
      ISolidlyV3Pool(beforeExecutionInput.pool).positions(beforeExecutionInput.positionKey);

    return abi.encode(initialLiquidity);
  }

  function _afterExecutionZapInSolidlyV3(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {
    SolidlyV3BeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    ZapInSolidlyV3AfterExecutionInput calldata afterExecutionInput;
    assembly ("memory-safe") {
      afterExecutionInput := _afterExecutionInput.offset
    }

    uint256 initialLiquidity = _beforeExecutionOutput.decodeUint256();
    (uint256 currentLiquidity,,) =
      ISolidlyV3Pool(beforeExecutionInput.pool).positions(beforeExecutionInput.positionKey);

    require(
      currentLiquidity >= initialLiquidity + afterExecutionInput.minLiquidity,
      ZapInSolidlyV3InsufficientLiquidity()
    );
  }
}
