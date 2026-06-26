// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingActionAdapter} from '../../../interfaces/modules/lending/ILendingActionAdapter.sol';
import '../../../libraries/BitMask.sol';
import {CommonLibrary} from '../../../libraries/CommonLibrary.sol';
import {BoolAddress} from '../../../types/BoolAddress.sol';

import {IController} from '../../../vendors/llama-lend/IController.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

contract LLamaLendActionAdapter is ILendingActionAdapter {
  using CalldataDecoder for bytes;
  using CommonLibrary for *;

  uint256 internal constant APPROVAL_FLAG_OFFSET = 160;
  uint256 internal constant MINT_FLAG_OFFSET = 161;
  uint256 internal constant N_BANDS_OFFSET = 162;

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
    (IController controller,,,) = _decodeLendingContext(lendingContext);

    uint256[4] memory userState = IController(controller).user_state(user);
    collateralAmount = userState[0];
    debtAmount = userState[2];
  }

  function supplyCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) external payable {
    (IController controller, bool approvalFlag,,) = _decodeLendingContext(lendingContext);

    if (approvalFlag) {
      collateralToken.forceApproveInf(address(controller));
    }
    controller.add_collateral(supplyAmount, onBehalfOf);
  }

  function withdrawCollateral(
    bytes calldata lendingContext,
    address, // collateralToken
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    if (onBehalfOf != address(this)) {
      revert WithdrawCollateralOnBehalfOfNotSupported();
    }

    (IController controller,, bool mintFlag,) = _decodeLendingContext(lendingContext);
    _withdrawCollateral(controller, mintFlag, withdrawAmount);
  }

  function borrow(
    bytes calldata lendingContext,
    address, // debtToken
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    if (onBehalfOf != address(this)) {
      revert BorrowOnBehalfOfNotSupported();
    }

    _supplyCollateralAndBorrow(lendingContext, address(0), 0, borrowAmount);
  }

  function repay(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) external payable {
    (IController controller, bool approvalFlag, bool mintFlag,) =
      _decodeLendingContext(lendingContext);
    _repay(controller, approvalFlag, mintFlag, debtToken, repayAmount, onBehalfOf);
  }

  function supplyCollateralAndBorrow(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address, // debtToken
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    if (onBehalfOf != address(this)) {
      revert BorrowOnBehalfOfNotSupported();
    }

    _supplyCollateralAndBorrow(lendingContext, collateralToken, supplyAmount, borrowAmount);
  }

  function repayAndWithdrawCollateral(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address, // collateralToken
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    if (onBehalfOf != address(this)) {
      revert WithdrawCollateralOnBehalfOfNotSupported();
    }

    (IController controller, bool approvalFlag, bool mintFlag,) =
      _decodeLendingContext(lendingContext);
    _repay(controller, approvalFlag, mintFlag, debtToken, repayAmount, address(this));
    _withdrawCollateral(controller, mintFlag, withdrawAmount);
  }

  function _supplyCollateralAndBorrow(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    uint256 borrowAmount
  ) internal {
    (IController controller, bool approvalFlag,, uint256 nBands) =
      _decodeLendingContext(lendingContext);

    if (approvalFlag) {
      collateralToken.forceApproveInf(address(controller));
    }

    // nBands != 0 means new loan
    if (nBands != 0) {
      controller.create_loan(supplyAmount, borrowAmount, nBands);
    } else {
      controller.borrow_more(supplyAmount, borrowAmount);
    }
  }

  function _repay(
    IController controller,
    bool approvalFlag,
    bool mintFlag,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) internal {
    if (approvalFlag) {
      debtToken.forceApproveInf(address(controller));
    }

    if (mintFlag) {
      controller.repay(repayAmount, onBehalfOf, 2 ** 255 - 1, false);
    } else {
      controller.repay(repayAmount, onBehalfOf);
    }
  }

  function _withdrawCollateral(IController controller, bool mintFlag, uint256 withdrawAmount)
    internal
  {
    if (controller.debt(address(this)) > 0) {
      if (mintFlag) {
        controller.remove_collateral(withdrawAmount, false);
      } else {
        controller.remove_collateral(withdrawAmount);
      }
    }
  }

  function _decodeLendingContext(bytes calldata lendingContext)
    internal
    pure
    returns (IController controller, bool approvalFlag, bool mintFlag, uint256 nBands)
  {
    uint256 poolData = lendingContext.decodeUint256();
    assembly ('memory-safe') {
      controller := and(poolData, MASK_160_BITS)
      approvalFlag := and(shr(APPROVAL_FLAG_OFFSET, poolData), MASK_1_BIT)
      mintFlag := and(shr(MINT_FLAG_OFFSET, poolData), MASK_1_BIT)
      nBands := shr(N_BANDS_OFFSET, poolData)
    }
  }
}
