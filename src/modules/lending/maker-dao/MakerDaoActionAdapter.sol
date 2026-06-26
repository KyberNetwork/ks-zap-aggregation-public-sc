// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingActionAdapter} from '../../../interfaces/modules/lending/ILendingActionAdapter.sol';
import {CommonLibrary} from '../../../libraries/CommonLibrary.sol';
import {BoolAddress} from '../../../types/BoolAddress.sol';

import {DaiJoinLike} from '../../../vendors/maker-dao/DaiJoinLike.sol';
import {GemJoinLike} from '../../../vendors/maker-dao/GemJoinLike.sol';
import {JugLike} from '../../../vendors/maker-dao/JugLike.sol';
import {VatLike} from '../../../vendors/maker-dao/VatLike.sol';

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

contract MakerDaoActionAdapter is ILendingActionAdapter {
  using CalldataDecoder for bytes;
  using CommonLibrary for address;

  uint256 internal constant RAY = 1e27;

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
    (GemJoinLike gemJoin,, JugLike jug,) = _decodeLendingContext(lendingContext);

    VatLike vat = gemJoin.vat();
    bytes32 ilk = gemJoin.ilk();

    (uint256 ink, uint256 art) = vat.urns(ilk, user);
    collateralAmount = _convertFrom18(ink, gemJoin.dec());

    debtAmount = art * _getRate(jug, vat, ilk) / RAY;
  }

  function supplyCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) external payable {
    _supplyCollateralAndBorrow(lendingContext, collateralToken, supplyAmount, 0, onBehalfOf);
  }

  function withdrawCollateral(
    bytes calldata lendingContext,
    address, // collateralToken
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    _repayAndWithdrawCollateral(lendingContext, address(0), 0, withdrawAmount, onBehalfOf);
  }

  function borrow(
    bytes calldata lendingContext,
    address, // debtToken
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    _supplyCollateralAndBorrow(lendingContext, address(0), 0, borrowAmount, onBehalfOf);
  }

  function repay(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) external payable {
    _repayAndWithdrawCollateral(lendingContext, debtToken, repayAmount, 0, onBehalfOf);
  }

  function supplyCollateralAndBorrow(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address, // debtToken
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    _supplyCollateralAndBorrow(
      lendingContext, collateralToken, supplyAmount, borrowAmount, onBehalfOf
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
    _repayAndWithdrawCollateral(lendingContext, debtToken, repayAmount, withdrawAmount, onBehalfOf);
  }

  function _supplyCollateralAndBorrow(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    uint256 borrowAmount,
    address onBehalfOf
  ) internal {
    (GemJoinLike gemJoin, DaiJoinLike daiJoin, JugLike jug, bool approvalFlag) =
      _decodeLendingContext(lendingContext);

    VatLike vat = gemJoin.vat();
    bytes32 ilk = gemJoin.ilk();

    if (supplyAmount > 0) {
      if (approvalFlag) {
        collateralToken.forceApproveInf(address(gemJoin));
      }
      gemJoin.join(onBehalfOf, supplyAmount);
    }

    vat.frob(
      ilk,
      onBehalfOf,
      onBehalfOf,
      address(this),
      int256(_convertTo18(supplyAmount, gemJoin.dec())),
      int256(Math.ceilDiv(borrowAmount * RAY, jug.drip(ilk)))
    );

    if (borrowAmount > 0) {
      if (approvalFlag) {
        vat.hope(address(daiJoin));
      }
      daiJoin.exit(address(this), borrowAmount);
    }
  }

  function _repayAndWithdrawCollateral(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    uint256 withdrawAmount,
    address onBehalfOf
  ) internal {
    (GemJoinLike gemJoin, DaiJoinLike daiJoin,, bool approvalFlag) =
      _decodeLendingContext(lendingContext);

    VatLike vat = gemJoin.vat();
    bytes32 ilk = gemJoin.ilk();

    (uint256 ink, uint256 art) = vat.urns(ilk, onBehalfOf);
    (, uint256 rate,,,) = vat.ilks(ilk);

    uint256 dink;
    if (withdrawAmount == type(uint256).max) {
      dink = ink;
    } else {
      dink = Math.min(ink, _convertTo18(withdrawAmount, gemJoin.dec()));
    }

    uint256 dart;
    if (repayAmount == type(uint256).max) {
      dart = art;
    } else {
      dart = Math.min(art, repayAmount * RAY / rate);
    }

    if (dart > 0) {
      if (approvalFlag) {
        debtToken.forceApproveInf(address(daiJoin));
      }
      daiJoin.join(address(this), Math.ceilDiv(dart * rate, RAY));
    }

    vat.frob(ilk, onBehalfOf, onBehalfOf, address(this), -int256(dink), -int256(dart));

    if (dink > 0) {
      if (onBehalfOf != address(this)) {
        vat.flux(ilk, onBehalfOf, address(this), dink);
      }
      gemJoin.exit(address(this), _convertFrom18(dink, gemJoin.dec()));
    }
  }

  // 0: [1 bit approvalFlag] [160 bits gem join address]
  // 1: [160 bits dai join address]
  // 2: [160 bits jug address]
  function _decodeLendingContext(bytes calldata lendingContext)
    internal
    pure
    returns (GemJoinLike gemJoin, DaiJoinLike daiJoin, JugLike jug, bool approvalFlag)
  {
    BoolAddress first = BoolAddress.wrap(lendingContext.decodeUint256());
    gemJoin = GemJoinLike(first.addressValue());
    approvalFlag = first.boolValue();
    daiJoin = DaiJoinLike(lendingContext.decodeAddress(1));
    jug = JugLike(lendingContext.decodeAddress(2));
  }

  function _convertTo18(uint256 amount, uint256 decimals) internal pure returns (uint256) {
    unchecked {
      return amount * 10 ** (18 - decimals);
    }
  }

  function _convertFrom18(uint256 amount, uint256 decimals) internal pure returns (uint256) {
    unchecked {
      return amount / 10 ** (18 - decimals);
    }
  }

  function _getRate(JugLike jug, VatLike vat, bytes32 ilk) internal view returns (uint256 rate) {
    (, uint256 prev,,,) = vat.ilks(ilk);
    (uint256 duty, uint256 rho) = jug.ilks(ilk);

    rate = _rpow(jug.base() + duty, block.timestamp - rho, RAY) * prev / RAY;
  }

  function _rpow(uint256 x, uint256 n, uint256 b) internal pure returns (uint256 z) {
    assembly {
      switch x
      case 0 {
        switch n
        case 0 { z := b }
        default { z := 0 }
      }
      default {
        switch mod(n, 2)
        case 0 { z := b }
        default { z := x }
        let half := div(b, 2) // for rounding.
        for { n := div(n, 2) } n { n := div(n, 2) } {
          let xx := mul(x, x)
          if iszero(eq(div(xx, x), x)) { revert(0, 0) }
          let xxRound := add(xx, half)
          if lt(xxRound, xx) { revert(0, 0) }
          x := div(xxRound, b)
          if mod(n, 2) {
            let zx := mul(z, x)
            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) }
            let zxRound := add(zx, half)
            if lt(zxRound, zx) { revert(0, 0) }
            z := div(zxRound, b)
          }
        }
      }
    }
  }
}
