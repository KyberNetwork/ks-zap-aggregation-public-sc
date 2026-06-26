// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingActionAdapter} from '../../../interfaces/modules/lending/ILendingActionAdapter.sol';
import {CommonLibrary} from '../../../libraries/CommonLibrary.sol';
import {BoolAddress} from '../../../types/BoolAddress.sol';

import {IEVC} from '../../../vendors/euler-v2/IEVC.sol';
import {IEVault} from '../../../vendors/euler-v2/IEVault.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

contract EulerV2ActionAdapter is ILendingActionAdapter {
  using CalldataDecoder for bytes;
  using CommonLibrary for address;

  function getPosition(
    bytes calldata lendingContext,
    address, // collateralToken,
    address, // debtToken,
    address user
  )
    external
    view
    returns (uint256 collateralAmount, uint256 debtAmount)
  {
    (IEVault collateralVault, IEVault debtVault,) = _decodeLendingContext(lendingContext);
    collateralAmount = collateralVault.convertToAssets(collateralVault.balanceOf(user));
    debtAmount = debtVault.debtOf(user);
  }

  function supplyCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) external payable {
    (IEVault collateralVault, IEVault debtVault, bool approvalFlag) =
      _decodeLendingContext(lendingContext);
    _supplyCollateralAndBorrow(
      collateralVault, debtVault, approvalFlag, collateralToken, supplyAmount, 0, onBehalfOf
    );
  }

  function withdrawCollateral(
    bytes calldata lendingContext,
    address, // collateralToken
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    (IEVault collateralVault, IEVault debtVault,) = _decodeLendingContext(lendingContext);
    _repayAndWithdrawCollateral(
      collateralVault, debtVault, false, address(0), 0, withdrawAmount, onBehalfOf
    );
  }

  function borrow(
    bytes calldata lendingContext,
    address, // debtToken
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    (IEVault collateralVault, IEVault debtVault, bool approvalFlag) =
      _decodeLendingContext(lendingContext);
    _supplyCollateralAndBorrow(
      collateralVault, debtVault, approvalFlag, address(0), 0, borrowAmount, onBehalfOf
    );
  }

  function repay(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) external payable {
    (IEVault collateralVault, IEVault debtVault, bool approvalFlag) =
      _decodeLendingContext(lendingContext);
    _repayAndWithdrawCollateral(
      collateralVault, debtVault, approvalFlag, debtToken, repayAmount, 0, onBehalfOf
    );
  }

  function supplyCollateralAndBorrow(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address, // debtToken
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    (IEVault collateralVault, IEVault debtVault, bool approvalFlag) =
      _decodeLendingContext(lendingContext);
    _supplyCollateralAndBorrow(
      collateralVault,
      debtVault,
      approvalFlag,
      collateralToken,
      supplyAmount,
      borrowAmount,
      onBehalfOf
    );
  }

  function repayAndWithdrawCollateral(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address, // collateralToken
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    (IEVault collateralVault, IEVault debtVault, bool approvalFlag) =
      _decodeLendingContext(lendingContext);
    _repayAndWithdrawCollateral(
      collateralVault, debtVault, approvalFlag, debtToken, repayAmount, withdrawAmount, onBehalfOf
    );
  }

  function _supplyCollateralAndBorrow(
    IEVault collateralVault,
    IEVault debtVault,
    bool approvalFlag,
    address collateralToken,
    uint256 supplyAmount,
    uint256 borrowAmount,
    address onBehalfOf
  ) internal {
    IEVC evc = IEVC(collateralVault.EVC());

    uint256 batchSize = 0;

    if (supplyAmount > 0) {
      if (approvalFlag) {
        batchSize++;
        collateralToken.forceApproveInf(address(collateralVault));
      }
      batchSize++;
    }

    if (borrowAmount > 0) {
      if (approvalFlag) {
        batchSize++;
      }
      batchSize++;
    }

    IEVC.BatchItem[] memory items = new IEVC.BatchItem[](batchSize);
    uint256 batchIndex = 0;

    if (supplyAmount > 0) {
      if (approvalFlag) {
        items[batchIndex++] = IEVC.BatchItem({
          targetContract: address(evc),
          onBehalfOfAccount: address(0),
          value: 0,
          data: abi.encodeCall(evc.enableCollateral, (onBehalfOf, address(collateralVault)))
        });
      }

      items[batchIndex++] = IEVC.BatchItem({
        targetContract: address(collateralVault),
        onBehalfOfAccount: address(this),
        value: 0,
        data: abi.encodeCall(collateralVault.deposit, (supplyAmount, onBehalfOf))
      });
    }

    if (borrowAmount > 0) {
      if (approvalFlag) {
        items[batchIndex++] = IEVC.BatchItem({
          targetContract: address(evc),
          onBehalfOfAccount: address(0),
          value: 0,
          data: abi.encodeCall(evc.enableController, (onBehalfOf, address(debtVault)))
        });
      }

      items[batchIndex++] = IEVC.BatchItem({
        targetContract: address(debtVault),
        onBehalfOfAccount: onBehalfOf,
        value: 0,
        data: abi.encodeCall(debtVault.borrow, (borrowAmount, address(this)))
      });
    }

    evc.batch(items);
  }

  function _repayAndWithdrawCollateral(
    IEVault collateralVault,
    IEVault debtVault,
    bool approvalFlag,
    address debtToken,
    uint256 repayAmount,
    uint256 withdrawAmount,
    address onBehalfOf
  ) internal {
    IEVC evc = IEVC(collateralVault.EVC());

    IEVC.BatchItem[] memory items =
      new IEVC.BatchItem[]((repayAmount > 0 ? 1 : 0) + (withdrawAmount > 0 ? 1 : 0));

    uint256 batchIndex = 0;

    if (repayAmount > 0) {
      if (approvalFlag) {
        debtToken.forceApproveInf(address(debtVault));
      }

      if (repayAmount != type(uint256).max) {
        repayAmount = Math.min(debtVault.debtOf(onBehalfOf), repayAmount);
      }
      items[batchIndex++] = IEVC.BatchItem({
        targetContract: address(debtVault),
        onBehalfOfAccount: address(this),
        value: 0,
        data: abi.encodeCall(debtVault.repay, (repayAmount, onBehalfOf))
      });
    }

    if (withdrawAmount > 0) {
      uint256 withdrawShares;
      if (withdrawAmount == type(uint256).max) {
        withdrawShares = type(uint256).max;
      } else {
        withdrawShares = Math.min(
          collateralVault.balanceOf(onBehalfOf), // user's supply shares
          collateralVault.convertToShares(withdrawAmount) + 1 // required shares to withdraw
        );
      }

      /// @dev If this contract is authorized, it can act on behalf of the user
      bool isAuthorized = evc.isAccountOperatorAuthorized(onBehalfOf, address(this));

      items[batchIndex++] = IEVC.BatchItem({
        targetContract: address(collateralVault),
        onBehalfOfAccount: isAuthorized ? onBehalfOf : address(this),
        value: 0,
        data: abi.encodeCall(collateralVault.redeem, (withdrawShares, address(this), onBehalfOf))
      });
    }

    evc.batch(items);
  }

  // 0: [1 bit approvalFlag] [160 bits collateral vault address]
  // 1: [160 bits debt vault address]
  function _decodeLendingContext(bytes calldata lendingContext)
    internal
    pure
    returns (IEVault collateralVault, IEVault debtVault, bool approvalFlag)
  {
    BoolAddress first = BoolAddress.wrap(lendingContext.decodeUint256());
    collateralVault = IEVault(first.addressValue());
    debtVault = IEVault(lendingContext.decodeAddress(1));
    approvalFlag = first.boolValue();
  }
}
