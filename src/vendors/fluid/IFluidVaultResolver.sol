//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFluidVault} from './IFluidVault.sol';

interface IFluidVaultResolver {
  struct UserPosition {
    uint256 nftId;
    address owner;
    bool isLiquidated;
    bool isSupplyPosition; // if true that means borrowing is 0
    int256 tick;
    uint256 tickId;
    uint256 beforeSupply;
    uint256 beforeBorrow;
    uint256 beforeDustBorrow;
    uint256 supply;
    uint256 borrow;
    uint256 dustBorrow;
  }

  function FACTORY() external view returns (address);

  function positionByNftId(uint256 nftId_) external view returns (UserPosition memory userPosition_);

  function positionsNftIdOfUser(address user_) external view returns (uint256[] memory nftIds_);

  function vaultByNftId(uint256 nftId_) external view returns (address vault_);

  function getVaultVariablesRaw(address vault_) external view returns (uint256);

  function getVaultVariables2Raw(address vault_) external view returns (uint256);

  function getTickHasDebtRaw(address vault_, int256 key_) external view returns (uint256);

  function getTickDataRaw(address vault_, int256 tick_) external view returns (uint256);

  function getBranchDataRaw(address vault_, uint256 branch_) external view returns (uint256);

  function getPositionDataRaw(address vault_, uint256 positionId_) external view returns (uint256);

  function getAllVaultsAddresses() external view returns (address[] memory vaults_);
}
