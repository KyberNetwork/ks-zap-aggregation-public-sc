// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IKSZapExecutor {
  function executeZap(bytes calldata data) external payable returns (bytes memory result);
}
