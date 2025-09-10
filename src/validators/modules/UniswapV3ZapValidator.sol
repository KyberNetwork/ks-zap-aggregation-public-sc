// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BytesHelper} from '../../libraries/BytesHelper.sol';

import {IUniswapV3ZapValidator} from
  '../../interfaces/validators/modules/IUniswapV3ZapValidator.sol';
import {IUniswapV3PosM} from '../../interfaces/vendors/uniswap-v3/IUniswapV3PosM.sol';

contract UniswapV3ZapValidator is IUniswapV3ZapValidator {
  function _beforeExecution_UniswapV3Fork(bytes calldata _beforeExecutionInput)
    internal
    view
    returns (bytes memory)
  {
    UniswapV3Fork_BeforeExecutionInput memory beforeExecutionInput =
      abi.decode(_beforeExecutionInput, (UniswapV3Fork_BeforeExecutionInput));

    if (beforeExecutionInput.tokenId == 0) {
      return abi.encode(IUniswapV3PosM(beforeExecutionInput.posManager).totalSupply());
    } else {
      (, bytes memory positionData) = beforeExecutionInput.posManager.staticcall(
        abi.encodeCall(IUniswapV3PosM.positions, (beforeExecutionInput.tokenId))
      );

      uint256 liquidityOffset = beforeExecutionInput.positionDataOffsets.at(0);
      uint256 initialLiquidity = BytesHelper.mloadUint256(positionData, liquidityOffset * 32);

      return abi.encode(initialLiquidity);
    }
  }

  function _afterExecution_ZapIn__UniswapV3Fork(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {
    UniswapV3Fork_BeforeExecutionInput memory beforeExecutionInput =
      abi.decode(_beforeExecutionInput, (UniswapV3Fork_BeforeExecutionInput));
    ZapIn__UniswapV3Fork_AfterExecutionInput memory afterExecutionInput =
      abi.decode(_afterExecutionInput, (ZapIn__UniswapV3Fork_AfterExecutionInput));

    uint256 tokenId = beforeExecutionInput.tokenId;
    uint256 initialLiquidity;

    (, bytes memory positionData) = beforeExecutionInput.posManager.staticcall(
      abi.encodeCall(IUniswapV3PosM.positions, (beforeExecutionInput.tokenId))
    );

    if (tokenId == 0) {
      uint256 totalSupply = abi.decode(_beforeExecutionOutput, (uint256));
      tokenId = IUniswapV3PosM(beforeExecutionInput.posManager).tokenByIndex(totalSupply);

      uint256 tickLowerOffset = beforeExecutionInput.positionDataOffsets.at(1);
      int256 tickLower = BytesHelper.mloadInt256(positionData, tickLowerOffset * 32);
      require(tickLower == afterExecutionInput.tickLower, ZapIn__UniswapV3Fork__InvalidTickRange());

      uint256 tickUpperOffset = beforeExecutionInput.positionDataOffsets.at(2);
      int256 tickUpper = BytesHelper.mloadInt256(positionData, tickUpperOffset * 32);
      require(tickUpper == afterExecutionInput.tickUpper, ZapIn__UniswapV3Fork__InvalidTickRange());
    } else {
      initialLiquidity = abi.decode(_beforeExecutionOutput, (uint256));
    }

    uint256 liquidityOffset = beforeExecutionInput.positionDataOffsets.at(0);
    uint256 currentLiquidity = BytesHelper.mloadUint256(positionData, liquidityOffset * 32);
    require(
      currentLiquidity >= initialLiquidity + afterExecutionInput.minLiquidity,
      ZapIn__UniswapV3Fork__InsufficientLiquidity()
    );

    require(
      IUniswapV3PosM(beforeExecutionInput.posManager).ownerOf(tokenId)
        == afterExecutionInput.recipient,
      UniswapV3Fork__InvalidPositionOwner()
    );
  }

  function _afterExecution_Remove__UniswapV3Fork(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {
    UniswapV3Fork_BeforeExecutionInput memory beforeExecutionInput =
      abi.decode(_beforeExecutionInput, (UniswapV3Fork_BeforeExecutionInput));
    Remove__UniswapV3Fork_AfterExecutionInput memory afterExecutionInput =
      abi.decode(_afterExecutionInput, (Remove__UniswapV3Fork_AfterExecutionInput));
    uint256 initialLiquidity = abi.decode(_beforeExecutionOutput, (uint256));

    (, bytes memory positionData) = beforeExecutionInput.posManager.staticcall(
      abi.encodeCall(IUniswapV3PosM.positions, (beforeExecutionInput.tokenId))
    );

    uint256 liquidityOffset = beforeExecutionInput.positionDataOffsets.at(0);
    uint256 currentLiquidity = BytesHelper.mloadUint256(positionData, liquidityOffset * 32);
    require(
      currentLiquidity + afterExecutionInput.liquidityRemoved == initialLiquidity,
      Remove__UniswapV3Fork__InvalidLiquidity()
    );

    require(
      IUniswapV3PosM(beforeExecutionInput.posManager).ownerOf(beforeExecutionInput.tokenId)
        == afterExecutionInput.recipient,
      UniswapV3Fork__InvalidPositionOwner()
    );
  }
}
