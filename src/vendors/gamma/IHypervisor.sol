// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

interface IHypervisor {
  function withdraw(uint256, address, address, uint256[4] memory)
    external
    returns (uint256, uint256);
}
