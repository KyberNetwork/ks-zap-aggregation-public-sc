// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISteerVault {
  function deposit(
    uint256 amount0,
    uint256 amount1,
    uint256 amount0Min,
    uint256 amount1Min,
    address recipient
  ) external returns (uint256 shares, uint256 amount0Used, uint256 amount1Used);
}
