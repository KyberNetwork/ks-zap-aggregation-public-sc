// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721sZapValidator} from '../../interfaces/validators/part-1/IERC721sZapValidator.sol';

import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';

contract ERC721sZapValidator is IERC721sZapValidator {
  function _afterExecutionZapERC721s(
    bytes calldata, // _beforeExecutionInput
    bytes calldata, // _beforeExecutionOutput
    bytes calldata _afterExecutionInput
  ) internal view {
    ZapERC721sAfterExecutionInput calldata afterExecutionInput;
    assembly ('memory-safe') {
      afterExecutionInput := add(
        _afterExecutionInput.offset,
        calldataload(_afterExecutionInput.offset)
      )
    }

    for (uint256 i = 0; i < afterExecutionInput.tokenIds.length; i++) {
      require(
        IERC721(afterExecutionInput.tokens[i]).ownerOf(afterExecutionInput.tokenIds[i])
          == afterExecutionInput.recipient,
        ZapERC721sIncorrectOwner()
      );
    }
  }
}
