// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721sZapValidator {
  error ZapERC721sIncorrectOwner();

  struct ZapERC721sAfterExecutionInput {
    address[] tokens;
    uint256[] tokenIds;
    address recipient;
  }
}
