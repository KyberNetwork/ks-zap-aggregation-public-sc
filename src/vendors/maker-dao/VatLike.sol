// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface VatLike {
  function urns(bytes32, address) external view returns (uint256, uint256);
  function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
  function can(address, address) external view returns (uint256);
  function dai(address) external view returns (uint256);
  function hope(address) external;
  function flux(bytes32, address, address, uint256) external;
  function frob(bytes32, address, address, address, int256, int256) external;
  function move(address, address, uint256) external;
}
