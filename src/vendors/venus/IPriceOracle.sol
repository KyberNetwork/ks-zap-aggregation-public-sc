// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

interface IPriceOracle {
  function getPrice(address token) external view returns (uint256);

  function getUnderlyingPrice(address vToken) external view returns (uint256);
}
