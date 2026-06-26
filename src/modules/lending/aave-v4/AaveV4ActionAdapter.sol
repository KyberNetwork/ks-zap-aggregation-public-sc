// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingActionAdapter} from '../../../interfaces/modules/lending/ILendingActionAdapter.sol';
import {CommonLibrary} from '../../../libraries/CommonLibrary.sol';
import {BoolAddress} from '../../../types/BoolAddress.sol';

import {IGiverPositionManager} from '../../../vendors/aave-v4/IGiverPositionManager.sol';
import {ISpoke} from '../../../vendors/aave-v4/ISpoke.sol';
import {ITakerPositionManager} from '../../../vendors/aave-v4/ITakerPositionManager.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

contract AaveV4ActionAdapter is ILendingActionAdapter {
  using CalldataDecoder for bytes;
  using CommonLibrary for address;
  using TokenHelper for address;

  function getPosition(
    bytes calldata lendingContext,
    address, // collateralToken
    address, // debtToken
    address user
  )
    external
    view
    returns (uint256 collateralAmount, uint256 debtAmount)
  {
    (ISpoke spoke,,, uint256 colReserveId, uint256 debtReserveId,) =
      _decodeLendingContext(lendingContext);
    collateralAmount = spoke.getUserSuppliedAssets(colReserveId, user);
    debtAmount = spoke.getUserTotalDebt(debtReserveId, user);
  }

  function supplyCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) external payable {
    (
      ISpoke spoke,
      IGiverPositionManager giverPositionManager,,
      uint256 colReserveId,,
      bool approvalFlag
    ) = _decodeLendingContext(lendingContext);
    _supplyCollateral(
      spoke,
      giverPositionManager,
      colReserveId,
      approvalFlag,
      collateralToken,
      supplyAmount,
      onBehalfOf
    );
  }

  function withdrawCollateral(
    bytes calldata lendingContext,
    address, // collateralToken
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    (ISpoke spoke,, ITakerPositionManager takerPositionManager, uint256 colReserveId,,) =
      _decodeLendingContext(lendingContext);
    _withdrawCollateral(spoke, takerPositionManager, colReserveId, withdrawAmount, onBehalfOf);
  }

  function borrow(
    bytes calldata lendingContext,
    address, // debtToken
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    (ISpoke spoke,, ITakerPositionManager takerPositionManager,, uint256 debtReserveId,) =
      _decodeLendingContext(lendingContext);
    _borrow(spoke, takerPositionManager, debtReserveId, borrowAmount, onBehalfOf);
  }

  function repay(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) external payable {
    (
      ISpoke spoke,
      IGiverPositionManager giverPositionManager,,,
      uint256 debtReserveId,
      bool approvalFlag
    ) = _decodeLendingContext(lendingContext);
    _repay(
      spoke, giverPositionManager, debtReserveId, debtToken, approvalFlag, repayAmount, onBehalfOf
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
    (
      ISpoke spoke,
      IGiverPositionManager giverPositionManager,
      ITakerPositionManager takerPositionManager,
      uint256 colReserveId,
      uint256 debtReserveId,
      bool approvalFlag
    ) = _decodeLendingContext(lendingContext);

    _supplyCollateral(
      spoke,
      giverPositionManager,
      colReserveId,
      approvalFlag,
      collateralToken,
      supplyAmount,
      onBehalfOf
    );
    _borrow(spoke, takerPositionManager, debtReserveId, borrowAmount, onBehalfOf);
  }

  function repayAndWithdrawCollateral(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address, // collateralToken
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    (
      ISpoke spoke,
      IGiverPositionManager giverPositionManager,
      ITakerPositionManager takerPositionManager,
      uint256 colReserveId,
      uint256 debtReserveId,
      bool approvalFlag
    ) = _decodeLendingContext(lendingContext);
    _repay(
      spoke, giverPositionManager, debtReserveId, debtToken, approvalFlag, repayAmount, onBehalfOf
    );
    _withdrawCollateral(spoke, takerPositionManager, colReserveId, withdrawAmount, onBehalfOf);
  }

  function _supplyCollateral(
    ISpoke spoke,
    IGiverPositionManager giverPositionManager,
    uint256 colReserveId,
    bool approvalFlag,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) internal {
    if (onBehalfOf == address(this)) {
      if (approvalFlag) {
        collateralToken.forceApproveInf(address(spoke));
        spoke.setUsingAsCollateral(colReserveId, true, address(this));
      }
      spoke.supply(colReserveId, supplyAmount, address(this));
    } else {
      if (approvalFlag) {
        collateralToken.forceApproveInf(address(giverPositionManager));
      }
      giverPositionManager.supplyOnBehalfOf(address(spoke), colReserveId, supplyAmount, onBehalfOf);
    }
  }

  function _withdrawCollateral(
    ISpoke spoke,
    ITakerPositionManager takerPositionManager,
    uint256 colReserveId,
    uint256 withdrawAmount,
    address onBehalfOf
  ) internal {
    if (onBehalfOf == address(this)) {
      spoke.withdraw(colReserveId, withdrawAmount, address(this));
    } else {
      takerPositionManager.withdrawOnBehalfOf(
        address(spoke), colReserveId, withdrawAmount, onBehalfOf
      );
    }
  }

  function _borrow(
    ISpoke spoke,
    ITakerPositionManager takerPositionManager,
    uint256 debtReserveId,
    uint256 borrowAmount,
    address onBehalfOf
  ) internal {
    if (onBehalfOf == address(this)) {
      spoke.borrow(debtReserveId, borrowAmount, address(this));
    } else {
      takerPositionManager.borrowOnBehalfOf(address(spoke), debtReserveId, borrowAmount, onBehalfOf);
    }
  }

  function _repay(
    ISpoke spoke,
    IGiverPositionManager giverPositionManager,
    uint256 debtReserveId,
    address debtToken,
    bool approvalFlag,
    uint256 repayAmount,
    address onBehalfOf
  ) internal {
    if (onBehalfOf == address(this)) {
      if (approvalFlag) {
        debtToken.forceApproveInf(address(spoke));
      }
      spoke.repay(debtReserveId, repayAmount, address(this));
    } else {
      if (approvalFlag) {
        debtToken.forceApproveInf(address(giverPositionManager));
      }
      giverPositionManager.repayOnBehalfOf(address(spoke), debtReserveId, repayAmount, onBehalfOf);
    }
  }

  function _decodeLendingContext(bytes calldata lendingContext)
    internal
    pure
    returns (
      ISpoke spoke,
      IGiverPositionManager giverPositionManager,
      ITakerPositionManager takerPositionManager,
      uint256 colReserveId,
      uint256 debtReserveId,
      bool approvalFlag
    )
  {
    BoolAddress spokeContext = BoolAddress.wrap(lendingContext.decodeUint256());
    spoke = ISpoke(spokeContext.addressValue());
    approvalFlag = spokeContext.boolValue();

    giverPositionManager = IGiverPositionManager(lendingContext.decodeAddress(1));
    takerPositionManager = ITakerPositionManager(lendingContext.decodeAddress(2));
    colReserveId = lendingContext.decodeUint256(3);
    debtReserveId = lendingContext.decodeUint256(4);
  }
}
