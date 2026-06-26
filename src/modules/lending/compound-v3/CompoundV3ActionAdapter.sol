// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingActionAdapter} from '../../../interfaces/modules/lending/ILendingActionAdapter.sol';
import {CommonLibrary} from '../../../libraries/CommonLibrary.sol';
import {BoolAddress} from '../../../types/BoolAddress.sol';

import {ICometExt} from '../../../vendors/compound-v3/ICometExt.sol';
import {ICometMain} from '../../../vendors/compound-v3/ICometMain.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

contract CompoundV3ActionAdapter is ILendingActionAdapter {
  using CalldataDecoder for bytes;
  using CommonLibrary for address;

  function getPosition(
    bytes calldata lendingContext,
    address collateralToken,
    address, // debtToken
    address user
  ) external view returns (uint256 collateralAmount, uint256 debtAmount) {
    (address pool,) = _decodeLendingContext(lendingContext);
    collateralAmount = ICometExt(pool).collateralBalanceOf(user, collateralToken);
    debtAmount = ICometMain(pool).borrowBalanceOf(user);
  }

  function supplyCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) external payable {
    (address pool, bool approvalFlag) = _decodeLendingContext(lendingContext);
    _supplyCollateral(pool, approvalFlag, collateralToken, supplyAmount, onBehalfOf);
  }

  function withdrawCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    (address pool,) = _decodeLendingContext(lendingContext);
    _withdrawCollateral(pool, collateralToken, withdrawAmount, onBehalfOf);
  }

  function borrow(
    bytes calldata lendingContext,
    address debtToken,
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    (address pool,) = _decodeLendingContext(lendingContext);
    _borrow(pool, debtToken, borrowAmount, onBehalfOf);
  }

  function repay(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) external payable {
    (address pool, bool approvalFlag) = _decodeLendingContext(lendingContext);
    _repay(pool, approvalFlag, debtToken, repayAmount, onBehalfOf);
  }

  function supplyCollateralAndBorrow(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address debtToken,
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    (address pool, bool approvalFlag) = _decodeLendingContext(lendingContext);
    _supplyCollateral(pool, approvalFlag, collateralToken, supplyAmount, onBehalfOf);
    _borrow(pool, debtToken, borrowAmount, onBehalfOf);
  }

  function repayAndWithdrawCollateral(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address collateralToken,
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    (address pool, bool approvalFlag) = _decodeLendingContext(lendingContext);
    _repay(pool, approvalFlag, debtToken, repayAmount, onBehalfOf);
    _withdrawCollateral(pool, collateralToken, withdrawAmount, onBehalfOf);
  }

  function _supplyCollateral(
    address pool,
    bool approvalFlag,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) internal {
    if (approvalFlag) {
      collateralToken.forceApproveInf(address(pool));
    }
    ICometMain(pool).supplyTo(onBehalfOf, collateralToken, supplyAmount);
  }

  function _withdrawCollateral(
    address pool,
    address collateralToken,
    uint256 withdrawAmount,
    address onBehalfOf
  ) internal {
    withdrawAmount = Math.min(
      withdrawAmount, ICometExt(pool).collateralBalanceOf(onBehalfOf, collateralToken)
    );
    ICometMain(pool).withdrawFrom(onBehalfOf, address(this), collateralToken, withdrawAmount);
  }

  function _borrow(address pool, address debtToken, uint256 borrowAmount, address onBehalfOf)
    internal
  {
    ICometMain(pool).withdrawFrom(onBehalfOf, address(this), debtToken, borrowAmount);
  }

  function _repay(
    address pool,
    bool approvalFlag,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) internal {
    if (approvalFlag) {
      debtToken.forceApproveInf(address(pool));
    }

    if (repayAmount != type(uint256).max) {
      repayAmount = Math.min(repayAmount, ICometMain(pool).borrowBalanceOf(onBehalfOf));
    }
    ICometMain(pool).supplyTo(onBehalfOf, debtToken, repayAmount);
  }

  // 0: [1 bit approvalFlag] [160 bits pool address]
  function _decodeLendingContext(bytes calldata lendingContext)
    internal
    pure
    returns (address pool, bool approvalFlag)
  {
    BoolAddress poolInfo = BoolAddress.wrap(lendingContext.decodeUint256(0));

    pool = poolInfo.addressValue();
    approvalFlag = poolInfo.boolValue();
  }
}
