// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './VatLike.sol';

interface DaiJoinLike {
  function vat() external view returns (VatLike);
  function dai() external view returns (address);
  function join(address, uint256) external payable;
  function exit(address, uint256) external;
}
