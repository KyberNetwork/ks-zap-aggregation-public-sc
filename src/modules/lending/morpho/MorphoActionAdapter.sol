// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingActionAdapter} from '../../../interfaces/modules/lending/ILendingActionAdapter.sol';
import {CommonLibrary} from '../../../libraries/CommonLibrary.sol';
import {BoolAddress} from '../../../types/BoolAddress.sol';

import {IMorpho, MarketParams} from '../../../vendors/morpho/IMorpho.sol';
import {
  MarketParamsLib,
  MorphoBalancesLib,
  MorphoLib,
  SharesMathLib
} from '../../../vendors/morpho/MorphoBalancesLib.sol';

import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

contract MorphoActionAdapter is ILendingActionAdapter {
  using MorphoBalancesLib for *;
  using MorphoLib for IMorpho;
  using SharesMathLib for uint256;
  using MarketParamsLib for MarketParams;
  using CommonLibrary for address;

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
    (IMorpho morpho,, MarketParams calldata marketParams) = _decodeLendingContext(lendingContext);
    collateralAmount = morpho.collateral(marketParams.id(), user);
    debtAmount = morpho.expectedBorrowAssets(marketParams, user);
  }

  function supplyCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) external payable {
    (IMorpho morpho, bool approvalFlag, MarketParams calldata marketParams) =
      _decodeLendingContext(lendingContext);
    _supplyCollateral(morpho, approvalFlag, marketParams, supplyAmount, onBehalfOf);
  }

  function withdrawCollateral(
    bytes calldata lendingContext,
    address,
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    (IMorpho morpho,, MarketParams calldata marketParams) = _decodeLendingContext(lendingContext);
    _withdrawCollateral(morpho, marketParams, withdrawAmount, onBehalfOf);
  }

  function borrow(bytes calldata lendingContext, address, uint256 borrowAmount, address onBehalfOf)
    external
    payable
  {
    (IMorpho morpho,, MarketParams calldata marketParams) = _decodeLendingContext(lendingContext);
    _borrow(morpho, marketParams, borrowAmount, onBehalfOf);
  }

  function repay(bytes calldata lendingContext, address, uint256 repayAmount, address onBehalfOf)
    external
    payable
  {
    (IMorpho morpho, bool approvalFlag, MarketParams calldata marketParams) =
      _decodeLendingContext(lendingContext);
    _repay(morpho, approvalFlag, marketParams, repayAmount, onBehalfOf);
  }

  function supplyCollateralAndBorrow(
    bytes calldata lendingContext,
    address, // collateralToken
    uint256 supplyAmount,
    address, // debtToken
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    (IMorpho morpho, bool approvalFlag, MarketParams calldata marketParams) =
      _decodeLendingContext(lendingContext);
    _supplyCollateral(morpho, approvalFlag, marketParams, supplyAmount, onBehalfOf);
    _borrow(morpho, marketParams, borrowAmount, onBehalfOf);
  }

  function repayAndWithdrawCollateral(
    bytes calldata lendingContext,
    address, // debtToken
    uint256 repayAmount,
    address, // collateralToken
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    (IMorpho morpho, bool approvalFlag, MarketParams calldata marketParams) =
      _decodeLendingContext(lendingContext);
    _repay(morpho, approvalFlag, marketParams, repayAmount, onBehalfOf);
    _withdrawCollateral(morpho, marketParams, withdrawAmount, onBehalfOf);
  }

  function _supplyCollateral(
    IMorpho morpho,
    bool approvalFlag,
    MarketParams calldata marketParams,
    uint256 supplyAmount,
    address onBehalfOf
  ) internal {
    if (approvalFlag) {
      marketParams.collateralToken.forceApproveInf(address(morpho));
    }
    IMorpho(morpho).supplyCollateral(marketParams, supplyAmount, onBehalfOf, '');
  }

  function _withdrawCollateral(
    IMorpho morpho,
    MarketParams calldata marketParams,
    uint256 withdrawAmount,
    address onBehalfOf
  ) internal {
    uint256 collateral = MorphoLib.collateral(IMorpho(morpho), marketParams.id(), onBehalfOf);
    IMorpho(morpho)
      .withdrawCollateral(
        marketParams, Math.min(withdrawAmount, collateral), onBehalfOf, address(this)
      );
  }

  function _borrow(
    IMorpho morpho,
    MarketParams calldata marketParams,
    uint256 borrowAmount,
    address onBehalfOf
  ) internal {
    IMorpho(morpho).borrow(marketParams, borrowAmount, 0, onBehalfOf, address(this));
  }

  function _repay(
    IMorpho morpho,
    bool approvalFlag,
    MarketParams calldata marketParams,
    uint256 repayAmount,
    address onBehalfOf
  ) internal {
    if (approvalFlag) {
      marketParams.loanToken.forceApproveInf(address(morpho));
    }

    uint256 borrowShares = IMorpho(morpho).borrowShares(marketParams.id(), onBehalfOf);
    (,, uint256 totalBorrowAssets, uint256 totalBorrowShares) =
      IMorpho(morpho).expectedMarketBalances(marketParams);

    uint256 repayShares;
    if (repayAmount == type(uint256).max) {
      repayShares = type(uint256).max;
    } else {
      repayShares = repayAmount.toSharesDown(totalBorrowAssets, totalBorrowShares);
    }

    IMorpho(morpho).repay(marketParams, 0, Math.min(repayShares, borrowShares), onBehalfOf, '');
  }

  // 0: [1 bit approvalFlag] [160 bits morpho address]
  // 1 - 6: [5 * 256 bits market params]
  function _decodeLendingContext(bytes calldata lendingContext)
    internal
    pure
    returns (IMorpho morpho, bool approvalFlag, MarketParams calldata marketParams)
  {
    BoolAddress morphoContext;
    assembly ('memory-safe') {
      morphoContext := calldataload(lendingContext.offset)
      marketParams := add(lendingContext.offset, 0x20)
    }

    morpho = IMorpho(morphoContext.addressValue());
    approvalFlag = morphoContext.boolValue();
  }
}
