// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20sZapValidator} from '../../../interfaces/validators/modules/1/IERC20sZapValidator.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

contract ERC20sZapValidator is IERC20sZapValidator {
  using TokenHelper for address;
  using CalldataDecoder for bytes;

  function _beforeExecutionZapInERC20s(bytes calldata _beforeExecutionInput)
    internal
    view
    returns (bytes memory)
  {
    ZapInERC20sBeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput :=
        add(_beforeExecutionInput.offset, calldataload(_beforeExecutionInput.offset))
    }

    uint256[] memory initialBalances = new uint256[](beforeExecutionInput.tokens.length);
    for (uint256 i = 0; i < beforeExecutionInput.tokens.length; i++) {
      initialBalances[i] = beforeExecutionInput.tokens[i].balanceOf(beforeExecutionInput.recipient);
    }

    return abi.encode(initialBalances);
  }

  function _afterExecutionZapInERC20s(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {
    ZapInERC20sBeforeExecutionInput calldata beforeExecutionInput;
    assembly ("memory-safe") {
      beforeExecutionInput :=
        add(_beforeExecutionInput.offset, calldataload(_beforeExecutionInput.offset))
    }

    ZapInERC20sAfterExecutionInput calldata afterExecutionInput;
    assembly ("memory-safe") {
      afterExecutionInput :=
        add(_afterExecutionInput.offset, calldataload(_afterExecutionInput.offset))
    }

    uint256[] calldata initialBalances = _beforeExecutionOutput.decodeUint256Array(0);

    for (uint256 i = 0; i < beforeExecutionInput.tokens.length; i++) {
      require(
        beforeExecutionInput.tokens[i].balanceOf(beforeExecutionInput.recipient)
          >= initialBalances[i] + afterExecutionInput.minAmounts[i],
        ZapInERC20sInsufficientAmount()
      );
    }
  }
}
