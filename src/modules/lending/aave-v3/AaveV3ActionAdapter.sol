// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingActionAdapter} from '../../../interfaces/modules/lending/ILendingActionAdapter.sol';
import {CommonLibrary} from '../../../libraries/CommonLibrary.sol';
import {BoolAddress} from '../../../types/BoolAddress.sol';

import {DataTypes} from '../../../vendors/aave-v3/DataTypes.sol';
import {IPool} from '../../../vendors/aave-v3/IPool.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';
import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

contract AaveV3ActionAdapter is ILendingActionAdapter {
  using CalldataDecoder for bytes;
  using CommonLibrary for address;
  using TokenHelper for address;

  function getPosition(
    bytes calldata lendingContext,
    address collateralToken,
    address debtToken,
    address user
  ) external view returns (uint256 collateralAmount, uint256 debtAmount) {
    (IPool pool,) = _decodeLendingContext(lendingContext);
    DataTypes.ReserveDataLegacy memory reserveData = IPool(pool).getReserveData(collateralToken);
    collateralAmount = reserveData.aTokenAddress.balanceOf(user);

    reserveData = IPool(pool).getReserveData(debtToken);
    debtAmount = reserveData.variableDebtTokenAddress.balanceOf(user);
  }

  function supplyCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) external payable {
    (IPool pool, bool approvalFlag) = _decodeLendingContext(lendingContext);
    _supplyCollateral(pool, approvalFlag, collateralToken, supplyAmount, onBehalfOf);
  }

  function withdrawCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    (IPool pool,) = _decodeLendingContext(lendingContext);
    _withdrawCollateral(pool, collateralToken, withdrawAmount, onBehalfOf);
  }

  function borrow(
    bytes calldata lendingContext,
    address debtToken,
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    (IPool pool,) = _decodeLendingContext(lendingContext);
    _borrow(pool, debtToken, borrowAmount, onBehalfOf);
  }

  function repay(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) external payable {
    (IPool pool, bool approvalFlag) = _decodeLendingContext(lendingContext);
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
    (IPool pool, bool approvalFlag) = _decodeLendingContext(lendingContext);
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
    (IPool pool, bool approvalFlag) = _decodeLendingContext(lendingContext);
    _repay(pool, approvalFlag, debtToken, repayAmount, onBehalfOf);
    _withdrawCollateral(pool, collateralToken, withdrawAmount, onBehalfOf);
  }

  function _supplyCollateral(
    IPool pool,
    bool approvalFlag,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) internal {
    if (approvalFlag) {
      collateralToken.forceApproveInf(address(pool));
    }
    IPool(pool).supply(collateralToken, supplyAmount, onBehalfOf, 0);
  }

  function _withdrawCollateral(
    IPool pool,
    address collateralToken,
    uint256 withdrawAmount,
    address onBehalfOf
  ) internal {
    if (onBehalfOf != address(this)) {
      address aToken = IPool(pool).getReserveAToken(collateralToken);
      withdrawAmount = Math.min(withdrawAmount, aToken.balanceOf(onBehalfOf) - 1);
      aToken.safeTransferFrom(onBehalfOf, address(this), withdrawAmount + 1);
    }
    IPool(pool).withdraw(collateralToken, withdrawAmount, address(this));
  }

  function _borrow(IPool pool, address debtToken, uint256 borrowAmount, address onBehalfOf)
    internal
  {
    IPool(pool).borrow(debtToken, borrowAmount, 2, 0, onBehalfOf);
  }

  function _repay(
    IPool pool,
    bool approvalFlag,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) internal {
    if (approvalFlag) {
      debtToken.forceApproveInf(address(pool));
    }
    IPool(pool).repay(debtToken, repayAmount, 2, onBehalfOf);
  }

  // 0: [1 bit approvalFlag] [160 bits pool address]
  function _decodeLendingContext(bytes calldata lendingContext)
    internal
    pure
    returns (IPool pool, bool approvalFlag)
  {
    BoolAddress poolInfo = BoolAddress.wrap(lendingContext.decodeUint256());

    pool = IPool(poolInfo.addressValue());
    approvalFlag = poolInfo.boolValue();
  }
}
