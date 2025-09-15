// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPancakeInfinityZapValidator} from
  '../../../interfaces/validators/modules/1/IPancakeInfinityZapValidator.sol';
import {ICLPositionManager} from
  '../../../interfaces/vendors/pancake-infinity/ICLPositionManager.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';

contract PancakeInfinityZapValidator is IPancakeInfinityZapValidator {
  using CalldataDecoder for bytes;

  function _beforeExecutionPancakeInfinity(bytes calldata _beforeExecutionInput)
    internal
    view
    returns (bytes memory beforeExecutionOutput)
  {
    PancakeInfinityBeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    if (beforeExecutionInput.tokenId == 0) {
      return abi.encode(ICLPositionManager(beforeExecutionInput.posManager).nextTokenId());
    } else {
      return abi.encode(
        ICLPositionManager(beforeExecutionInput.posManager).getPositionLiquidity(
          beforeExecutionInput.tokenId
        )
      );
    }
  }

  function _afterExecutionZapInPancakeInfinity(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {
    PancakeInfinityBeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    ZapInPancakeInfinityAfterExecutionInput calldata afterExecutionInput;
    assembly ("memory-safe") {
      afterExecutionInput := _afterExecutionInput.offset
    }

    uint256 tokenId = beforeExecutionInput.tokenId;
    uint256 initialLiquidity;
    uint256 currentLiquidity;

    if (tokenId == 0) {
      tokenId = _beforeExecutionOutput.decodeUint256();

      int24 tickLower;
      int24 tickUpper;
      (, tickLower, tickUpper, currentLiquidity,,,) =
        ICLPositionManager(beforeExecutionInput.posManager).positions(tokenId);
      assembly ("memory-safe") {
        tickLower := signextend(2, tickLower)
        tickUpper := signextend(2, tickUpper)
      }

      require(
        tickLower == afterExecutionInput.tickLower && tickUpper == afterExecutionInput.tickUpper,
        ZapInPancakeInfinityInvalidTickRange()
      );
    } else {
      initialLiquidity = _beforeExecutionOutput.decodeUint256();
      currentLiquidity =
        ICLPositionManager(beforeExecutionInput.posManager).getPositionLiquidity(tokenId);
    }

    require(
      currentLiquidity >= initialLiquidity + afterExecutionInput.minLiquidity,
      ZapInPancakeInfinityInsufficientLiquidity()
    );

    require(
      ICLPositionManager(beforeExecutionInput.posManager).ownerOf(tokenId)
        == afterExecutionInput.recipient,
      PancakeInfinityInvalidPositionOwner()
    );
  }

  function _afterExecutionRemovePancakeInfinity(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {
    PancakeInfinityBeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    RemovePancakeInfinityAfterExecutionInput calldata afterExecutionInput;
    assembly ("memory-safe") {
      afterExecutionInput := _afterExecutionInput.offset
    }

    uint256 initialLiquidity = _beforeExecutionOutput.decodeUint256();
    uint256 currentLiquidity =
      ICLPositionManager(beforeExecutionInput.posManager).getPositionLiquidity(
        beforeExecutionInput.tokenId
      );

    require(
      currentLiquidity + afterExecutionInput.liquidityRemoved == initialLiquidity,
      RemovePancakeInfinityInvalidLiquidity()
    );

    require(
      ICLPositionManager(beforeExecutionInput.posManager).ownerOf(beforeExecutionInput.tokenId)
        == afterExecutionInput.recipient,
      PancakeInfinityInvalidPositionOwner()
    );
  }
}
