// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20sZapValidator} from '../../../interfaces/validators/modules/1/IERC20sZapValidator.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

contract ERC20sZapValidator is IERC20sZapValidator {
  using TokenHelper for address;

  function _beforeExecution_ZapIn__ERC20s(bytes calldata _beforeExecutionInput)
    internal
    view
    returns (bytes memory)
  {
    ZapIn__ERC20s_BeforeExecutionInput memory beforeExecutionInput =
      abi.decode(_beforeExecutionInput, (ZapIn__ERC20s_BeforeExecutionInput));

    uint256[] memory initialBalances = new uint256[](beforeExecutionInput.tokens.length);
    for (uint256 i = 0; i < beforeExecutionInput.tokens.length; i++) {
      initialBalances[i] = beforeExecutionInput.tokens[i].balanceOf(beforeExecutionInput.recipient);
    }

    return abi.encode(initialBalances);
  }

  function _afterExecution_ZapIn__ERC20s(
    bytes calldata _beforeExecutionInput,
    bytes calldata _beforeExecutionOutput,
    bytes calldata _afterExecutionInput
  ) internal view {
    ZapIn__ERC20s_BeforeExecutionInput memory beforeExecutionInput =
      abi.decode(_beforeExecutionInput, (ZapIn__ERC20s_BeforeExecutionInput));
    ZapIn__ERC20s_AfterExecutionInput memory afterExecutionInput =
      abi.decode(_afterExecutionInput, (ZapIn__ERC20s_AfterExecutionInput));

    uint256[] memory initialBalances = abi.decode(_beforeExecutionOutput, (uint256[]));

    for (uint256 i = 0; i < beforeExecutionInput.tokens.length; i++) {
      require(
        beforeExecutionInput.tokens[i].balanceOf(beforeExecutionInput.recipient)
          >= initialBalances[i] + afterExecutionInput.minAmounts[i],
        ZapIn__ERC20s__InsufficientAmount()
      );
    }
  }
}
