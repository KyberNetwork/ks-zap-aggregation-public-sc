// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISolidlyV2Pair {
  function token0() external view returns (address);
  function token1() external view returns (address);
  function totalSupply() external view returns (uint256);
  function getReserves() external view returns (uint256, uint256, uint256);
  function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
  function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
  function mint(address to) external returns (uint256 liquidity);
}
