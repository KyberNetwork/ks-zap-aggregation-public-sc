// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapExecutor} from 'src/interfaces/IKSZapExecutor.sol';

contract ZapExecutorMock is IKSZapExecutor {
  function executeZap(bytes calldata) external payable returns (bytes memory) {
    return '';
  }
}
