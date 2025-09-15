// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IUniswapV3ForkZapValidator} from
  '../../../interfaces/validators/modules/1/IUniswapV3ForkZapValidator.sol';
import {IUniswapV3NFT} from '../../../interfaces/vendors/uniswap-v3/IUniswapV3NFT.sol';
import {BytesHelper} from '../../../libraries/BytesHelper.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';

contract UniswapV3ForkZapValidator is IUniswapV3ForkZapValidator {
  using CalldataDecoder for bytes;

  function _beforeExecutionUniswapV3Fork(bytes calldata _beforeExecutionInput)
    internal
    view
    returns (bytes memory)
  {
    UniswapV3ForkBeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    if (beforeExecutionInput.tokenId == 0) {
      return abi.encode(IUniswapV3NFT(beforeExecutionInput.posManager).totalSupply());
    } else {
      (, bytes memory positionData) = beforeExecutionInput.posManager.staticcall(
        abi.encodeCall(IUniswapV3NFT.positions, (beforeExecutionInput.tokenId))
      );

      uint256 liquidityOffset = beforeExecutionInput.positionDataOffsets.at(0);
      uint256 initialLiquidity = BytesHelper.mloadUint256(positionData, liquidityOffset * 32);

      return abi.encode(initialLiquidity);
    }
  }

  function _afterExecutionZapInUniswapV3Fork(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {
    UniswapV3ForkBeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    ZapInUniswapV3ForkAfterExecutionInput calldata afterExecutionInput;
    assembly ("memory-safe") {
      afterExecutionInput := _afterExecutionInput.offset
    }

    uint256 tokenId = beforeExecutionInput.tokenId;
    uint256 initialLiquidity;

    (, bytes memory positionData) = beforeExecutionInput.posManager.staticcall(
      abi.encodeCall(IUniswapV3NFT.positions, (beforeExecutionInput.tokenId))
    );

    if (tokenId == 0) {
      uint256 totalSupply = _beforeExecutionOutput.decodeUint256();
      tokenId = IUniswapV3NFT(beforeExecutionInput.posManager).tokenByIndex(totalSupply);

      uint256 tickLowerOffset = beforeExecutionInput.positionDataOffsets.at(1);
      int256 tickLower = BytesHelper.mloadInt256(positionData, tickLowerOffset * 32);
      require(tickLower == afterExecutionInput.tickLower, ZapInUniswapV3ForkInvalidTickRange());

      uint256 tickUpperOffset = beforeExecutionInput.positionDataOffsets.at(2);
      int256 tickUpper = BytesHelper.mloadInt256(positionData, tickUpperOffset * 32);
      require(tickUpper == afterExecutionInput.tickUpper, ZapInUniswapV3ForkInvalidTickRange());
    } else {
      initialLiquidity = _beforeExecutionOutput.decodeUint256();
    }

    uint256 liquidityOffset = beforeExecutionInput.positionDataOffsets.at(0);
    uint256 currentLiquidity = BytesHelper.mloadUint256(positionData, liquidityOffset * 32);
    require(
      currentLiquidity >= initialLiquidity + afterExecutionInput.minLiquidity,
      ZapInUniswapV3ForkInsufficientLiquidity()
    );

    require(
      IUniswapV3NFT(beforeExecutionInput.posManager).ownerOf(tokenId)
        == afterExecutionInput.recipient,
      UniswapV3ForkInvalidPositionOwner()
    );
  }

  function _afterExecutionRemoveUniswapV3Fork(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {
    UniswapV3ForkBeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput := _beforeExecutionInput.offset
    }

    RemoveUniswapV3ForkAfterExecutionInput calldata afterExecutionInput;
    assembly ("memory-safe") {
      afterExecutionInput := _afterExecutionInput.offset
    }

    uint256 initialLiquidity = _beforeExecutionOutput.decodeUint256();

    (, bytes memory positionData) = beforeExecutionInput.posManager.staticcall(
      abi.encodeCall(IUniswapV3NFT.positions, (beforeExecutionInput.tokenId))
    );

    uint256 liquidityOffset = beforeExecutionInput.positionDataOffsets.at(0);
    uint256 currentLiquidity = BytesHelper.mloadUint256(positionData, liquidityOffset * 32);
    require(
      currentLiquidity + afterExecutionInput.liquidityRemoved == initialLiquidity,
      RemoveUniswapV3ForkInvalidLiquidity()
    );

    require(
      IUniswapV3NFT(beforeExecutionInput.posManager).ownerOf(beforeExecutionInput.tokenId)
        == afterExecutionInput.recipient,
      UniswapV3ForkInvalidPositionOwner()
    );
  }
}
