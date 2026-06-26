// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVToken {
  function mint() external payable;

  function mint(uint256 mintAmount) external returns (uint256);

  function mintBehalf(address receiver, uint256 mintAmount) external returns (uint256);

  function redeem(uint256 redeemTokens) external returns (uint256);

  function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

  function redeemUnderlyingBehalf(address redeemer, uint256 redeemAmount) external returns (uint256);

  function borrow(uint256 borrowAmount) external returns (uint256);

  function borrowBehalf(address borrower, uint256 borrowAmount) external returns (uint256);

  function repayBorrow() external payable;

  function repayBorrow(uint256 repayAmount) external returns (uint256);

  function repayBorrowBehalf(address borrower) external payable;

  function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

  function balanceOfUnderlying(address account) external returns (uint256);

  function borrowBalanceCurrent(address account) external returns (uint256);

  function underlying() external view returns (address);

  function comptroller() external view returns (address);
}
