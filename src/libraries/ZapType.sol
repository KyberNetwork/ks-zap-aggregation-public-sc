// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Contains the zap types
library ZapType {
  bytes32 internal constant ZapInUniswapV3Fork = keccak256('ZapInUniswapV3Fork');
  bytes32 internal constant RemoveUniswapV3Fork = keccak256('RemoveUniswapV3Fork');

  bytes32 internal constant ZapInERC20s = keccak256('ZapInERC20s');

  bytes32 internal constant ZapInSolidlyV3 = keccak256('ZapInSolidlyV3');

  bytes32 internal constant ZapInUniswapV4 = keccak256('ZapInUniswapV4');
  bytes32 internal constant RemoveUniswapV4 = keccak256('RemoveUniswapV4');

  bytes32 internal constant ZapInPancakeInfinity = keccak256('ZapInPancakeInfinity');
  bytes32 internal constant RemovePancakeInfinity = keccak256('RemovePancakeInfinity');
}
