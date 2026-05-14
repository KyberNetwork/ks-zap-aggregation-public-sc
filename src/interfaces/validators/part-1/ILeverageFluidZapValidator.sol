// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BalanceDelta} from '../../../vendors/uniswap-v4/BalanceDelta.sol';

interface ILeverageFluidZapValidator {
  error ZapLeverageFluidInvalidPositionOwner();
  error ZapLeverageFluidInvalidCollateralDelta();
  error ZapLeverageFluidInvalidDebtDelta();

  struct ZapLeverageFluidBeforeExecutionInput {
    address resolver;
    uint256 nftId;
    address collateralToken;
    address debtToken;
    address recipient;
  }

  struct ZapLeverageFluidAfterExecutionInput {
    BalanceDelta collateralDeltaRange;
    BalanceDelta debtDeltaRange;
  }
}
