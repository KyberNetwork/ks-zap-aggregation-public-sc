//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFluidVault} from './IFluidVault.sol';

interface IFluidVaultT2 is IFluidVault {
  function operate(
    uint256 nftId_,
    int256 newColToken0_,
    int256 newColToken1_,
    int256 colSharesMinMax_,
    int256 newDebt_,
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
    int256 perfectColShares_,
    int256 colToken0MinMax_,
    int256 colToken1MinMax_,
    int256 newDebt_,
    address to_
  )
    external
    payable
    returns (
      uint256, // nftId_
      int256[] memory r_
    );

  function liquidate(
    uint256 debtAmt_,
    uint256 colPerUnitDebt_, // col per unit is w.r.t debt shares and not token0/1 debt amount
    uint256 token0ColAmtPerUnitShares_, // in 1e18
    uint256 token1ColAmtPerUnitShares_, // in 1e18
    address to_,
    bool absorb_
  )
    external
    payable
    returns (uint256 actualDebt_, uint256 actualColShares_, uint256 token0Col_, uint256 token1Col_);

  function liquidatePerfect(
    uint256 debtAmt_,
    uint256 colPerUnitDebt_, // col per unit is w.r.t debt shares and not token0/1 debt amount
    uint256 token0ColAmtPerUnitShares_, // in 1e18
    uint256 token1ColAmtPerUnitShares_, // in 1e18
    address to_,
    bool absorb_
  )
    external
    payable
    returns (uint256 actualDebt_, uint256 actualColShares_, uint256 token0Col_, uint256 token1Col_);
}
