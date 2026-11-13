// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

interface IUniProxyETH {
  function deposit(
    uint256 deposit0,
    uint256 deposit1,
    address to,
    address pos,
    uint256[4] memory minIn,
    uint256 maxSlippage
  ) external returns (uint256 shares);

  function clearance() external view returns (address clearing);

  function getDepositAmount(address, address, uint256) external view returns (uint256, uint256);
}
