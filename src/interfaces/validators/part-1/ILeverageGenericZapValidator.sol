// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BalanceDelta} from '../../../vendors/uniswap-v4/BalanceDelta.sol';

interface ILeverageGenericZapValidator {
  error ZapLeverageGenericInvalidCollateralDelta();
  error ZapLeverageGenericInvalidDebtDelta();

  struct ZapLeverageGenericBeforeExecutionInput {
    address lendingAdapter;
    bytes lendingContext;
    address collateralToken;
    address debtToken;
    address recipient;
  }

  struct ZapLeverageGenericAfterExecutionInput {
    BalanceDelta collateralDeltaRange;
    BalanceDelta debtDeltaRange;
  }
}
