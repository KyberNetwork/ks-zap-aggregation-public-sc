// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ZapType {
  bytes32 internal constant ZapIn__UniswapV3Fork = keccak256('ZapIn__UniswapV3Fork');
  bytes32 internal constant Remove__UniswapV3Fork = keccak256('Remove__UniswapV3Fork');
  
  bytes32 internal constant ZapIn__ERC20s = keccak256('ZapIn__ERC20s');
}
