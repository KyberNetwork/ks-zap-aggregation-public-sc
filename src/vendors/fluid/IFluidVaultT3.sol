//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFluidVault} from './IFluidVault.sol';

interface IFluidVaultT3 is IFluidVault {
  function operate(
    uint256 nftId_,
    int256 newCol_,
    int256 newDebtToken0_,
    int256 newDebtToken1_,
    int256 debtSharesMinMax_,
    address to_
  )
    external
    payable
    returns (
      uint256, // nftId_
      int256, // final supply amount. if - then withdraw
      int256 // final borrow amount. if - then payback
    );

  function operatePerfect(
    uint256 nftId_,
    int256 newCol_,
    int256 perfectDebtShares_,
    int256 debtToken0MinMax_,
    int256 debtToken1MinMax_,
    address to_
  )
    external
    payable
    returns (
      uint256, // nftId_
      int256[] memory r_
    );

  function liquidate(
    uint256 token0DebtAmt_,
    uint256 token1DebtAmt_,
    uint256 debtSharesMin_,
    uint256 colPerUnitDebt_,
    address to_,
    bool absorb_
  ) external payable returns (uint256 actualDebtShares_, uint256 actualCol_);

  function liquidatePerfect(
    uint256 debtShares_,
    uint256 token0DebtAmtPerUnitShares_,
    uint256 token1DebtAmtPerUnitShares_,
    uint256 colPerUnitDebt_,
    address to_,
    bool absorb_
  )
    external
    payable
    returns (
      uint256 actualDebtShares_,
      uint256 token0Debt_,
      uint256 token1Debt_,
      uint256 actualCol_
    );
}
