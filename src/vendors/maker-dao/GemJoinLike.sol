// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './VatLike.sol';

interface GemJoinLike {
  function vat() external view returns (VatLike);
  function ilk() external view returns (bytes32);
  function gem() external view returns (address);
  function dec() external view returns (uint256);
  function join(address, uint256) external payable;
  function exit(address, uint256) external;
}
