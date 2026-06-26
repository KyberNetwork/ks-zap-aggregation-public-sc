// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IComptroller {
  function enterMarketBehalf(address onBehalf, address vToken) external returns (uint256);

  function enterMarkets(address[] calldata vTokens) external returns (uint256[] memory);

  function exitMarket(address vToken) external returns (uint256);

  function updateDelegate(address delegate, bool allowBorrows) external;
}
