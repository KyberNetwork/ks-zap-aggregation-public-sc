// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingActionAdapter} from '../../../interfaces/modules/lending/ILendingActionAdapter.sol';
import {CommonLibrary} from '../../../libraries/CommonLibrary.sol';
import {BoolAddress} from '../../../types/BoolAddress.sol';

import {IComptroller} from '../../../vendors/venus/IComptroller.sol';
import {IVToken} from '../../../vendors/venus/IVToken.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';
import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

contract VenusActionAdapter is ILendingActionAdapter {
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
    returns (uint256 collateralAmount, uint256 debtAmount)
  {
    (IVToken vCollateralToken, IVToken vDebtToken,) = _decodeLendingContext(lendingContext);
    collateralAmount = vCollateralToken.balanceOfUnderlying(user);
    debtAmount = vDebtToken.borrowBalanceCurrent(user);
  }

  function supplyCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) external payable {
    (IVToken vCollateralToken,, bool approvalFlag) = _decodeLendingContext(lendingContext);
    _supplyCollateral(vCollateralToken, approvalFlag, collateralToken, supplyAmount, onBehalfOf);
  }

  function withdrawCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    (IVToken vCollateralToken,,) = _decodeLendingContext(lendingContext);
    _withdrawCollateral(vCollateralToken, collateralToken, withdrawAmount, onBehalfOf);
  }

  function borrow(
    bytes calldata lendingContext,
    address debtToken,
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    (, IVToken vDebtToken, bool approvalFlag) = _decodeLendingContext(lendingContext);
    _borrow(vDebtToken, approvalFlag, debtToken, borrowAmount, onBehalfOf);
  }

  function repay(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) external payable {
    (, IVToken vDebtToken, bool approvalFlag) = _decodeLendingContext(lendingContext);
    _repay(vDebtToken, approvalFlag, debtToken, repayAmount, onBehalfOf);
  }

  function supplyCollateralAndBorrow(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address debtToken,
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    (IVToken vCollateralToken, IVToken vDebtToken, bool approvalFlag) =
      _decodeLendingContext(lendingContext);
    _supplyCollateral(vCollateralToken, approvalFlag, collateralToken, supplyAmount, onBehalfOf);
    _borrow(vDebtToken, approvalFlag, debtToken, borrowAmount, onBehalfOf);
  }

  function repayAndWithdrawCollateral(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address collateralToken,
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    (IVToken vCollateralToken, IVToken vDebtToken, bool approvalFlag) =
      _decodeLendingContext(lendingContext);
    _repay(vDebtToken, approvalFlag, debtToken, repayAmount, onBehalfOf);
    _withdrawCollateral(vCollateralToken, collateralToken, withdrawAmount, onBehalfOf);
  }

  function _supplyCollateral(
    IVToken vCollateralToken,
    bool approvalFlag,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) internal {
    if (approvalFlag) {
      collateralToken.forceApproveInf(address(vCollateralToken));
      _enterMarket(vCollateralToken, onBehalfOf);
    }

    if (collateralToken.isNative()) {
      if (onBehalfOf != address(this)) {
        revert SupplyCollateralOnBehalfOfNotSupported();
      }
      vCollateralToken.mint{value: supplyAmount}();
    } else {
      vCollateralToken.mintBehalf(onBehalfOf, supplyAmount);
    }
  }

  function _withdrawCollateral(
    IVToken vCollateralToken,
    address collateralToken,
    uint256 withdrawAmount,
    address onBehalfOf
  ) internal {
    withdrawAmount = Math.min(withdrawAmount, vCollateralToken.balanceOfUnderlying(onBehalfOf));

    if (onBehalfOf == address(this)) {
      vCollateralToken.redeemUnderlying(withdrawAmount);
    } else {
      if (collateralToken.isNative()) {
        revert WithdrawCollateralOnBehalfOfNotSupported();
      }

      vCollateralToken.redeemUnderlyingBehalf(onBehalfOf, withdrawAmount);
    }
  }

  function _borrow(
    IVToken vDebtToken,
    bool approvalFlag,
    address debtToken,
    uint256 borrowAmount,
    address onBehalfOf
  ) internal {
    if (approvalFlag) {
      _enterMarket(vDebtToken, onBehalfOf);
    }

    if (onBehalfOf == address(this)) {
      vDebtToken.borrow(borrowAmount);
    } else {
      if (debtToken.isNative()) {
        revert BorrowOnBehalfOfNotSupported();
      }

      vDebtToken.borrowBehalf(onBehalfOf, borrowAmount);
    }
  }

  function _repay(
    IVToken vDebtToken,
    bool approvalFlag,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) internal {
    if (approvalFlag) {
      debtToken.forceApproveInf(address(vDebtToken));
    }

    repayAmount = Math.min(repayAmount, vDebtToken.borrowBalanceCurrent(onBehalfOf));
    if (debtToken.isNative()) {
      vDebtToken.repayBorrowBehalf{value: repayAmount}(onBehalfOf);
    } else {
      vDebtToken.repayBorrowBehalf(onBehalfOf, repayAmount);
    }
  }

  function _enterMarket(IVToken vToken, address onBehalfOf) internal {
    IComptroller comptroller = IComptroller(vToken.comptroller());

    if (onBehalfOf == address(this)) {
      address[] memory vTokens = new address[](1);
      vTokens[0] = address(vToken);
      comptroller.enterMarkets(vTokens);
    } else {
      comptroller.enterMarketBehalf(onBehalfOf, address(vToken));
    }
  }

  function _decodeLendingContext(bytes calldata lendingContext)
    internal
    pure
    returns (IVToken vCollateralToken, IVToken vDebtToken, bool approvalFlag)
  {
    BoolAddress first = BoolAddress.wrap(lendingContext.decodeUint256(0));
    vCollateralToken = IVToken(first.addressValue());
    approvalFlag = first.boolValue();
    vDebtToken = IVToken(lendingContext.decodeAddress(1));
  }
}
