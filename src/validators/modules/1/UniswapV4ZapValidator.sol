// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV4ZapValidator} from
  '../../../interfaces/validators/modules/1/IUniswapV4ZapValidator.sol';
import {IPositionManager, PositionInfo} from '../../../vendors/uniswap-v4/IPositionManager.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';

contract UniswapV4ZapValidator is IUniswapV4ZapValidator {
  using CalldataDecoder for bytes;

  function _beforeExecutionUniswapV4(bytes calldata _beforeExecutionInput)
    internal
    view
    returns (bytes memory)
  {
    UniswapV4BeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    if (beforeExecutionInput.tokenId == 0) {
      return abi.encode(IPositionManager(beforeExecutionInput.posManager).nextTokenId());
    } else {
      return abi.encode(
        IPositionManager(beforeExecutionInput.posManager).getPositionLiquidity(
          beforeExecutionInput.tokenId
        )
      );
    }
  }

  function _afterExecutionZapInUniswapV4(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {
    UniswapV4BeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    ZapInUniswapV4AfterExecutionInput calldata afterExecutionInput;
    assembly ("memory-safe") {
      afterExecutionInput := _afterExecutionInput.offset
    }

    uint256 tokenId = beforeExecutionInput.tokenId;
    uint256 initialLiquidity;
    if (tokenId == 0) {
      tokenId = _beforeExecutionOutput.decodeUint256();
    } else {
      initialLiquidity = _beforeExecutionOutput.decodeUint256();
    }

    (, PositionInfo info) =
      IPositionManager(beforeExecutionInput.posManager).getPoolAndPositionInfo(tokenId);
    require(
      PositionInfo.unwrap(info) == afterExecutionInput.expectedPositionInfo,
      ZapInUniswapV4InvalidPositionInfo()
    );

    uint256 currentLiquidity =
      IPositionManager(beforeExecutionInput.posManager).getPositionLiquidity(tokenId);
    require(
      currentLiquidity >= initialLiquidity + afterExecutionInput.minLiquidity,
      ZapInUniswapV4InsufficientLiquidity()
    );

    require(
      IPositionManager(beforeExecutionInput.posManager).ownerOf(tokenId)
        == afterExecutionInput.recipient,
      UniswapV4InvalidPositionOwner()
    );
  }

  function _afterExecutionRemoveUniswapV4(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {
    UniswapV4BeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    RemoveUniswapV4AfterExecutionInput calldata afterExecutionInput;
    assembly ("memory-safe") {
      afterExecutionInput := _afterExecutionInput.offset
    }

    uint256 initialLiquidity = _beforeExecutionOutput.decodeUint256();
    uint256 currentLiquidity = IPositionManager(beforeExecutionInput.posManager)
      .getPositionLiquidity(beforeExecutionInput.tokenId);

    require(
      currentLiquidity + afterExecutionInput.liquidityRemoved == initialLiquidity,
      RemoveUniswapV4InvalidLiquidity()
    );

    require(
      IPositionManager(beforeExecutionInput.posManager).ownerOf(beforeExecutionInput.tokenId)
        == afterExecutionInput.recipient,
      UniswapV4InvalidPositionOwner()
    );
  }
}
