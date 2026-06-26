// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingActionAdapter} from '../../../interfaces/modules/lending/ILendingActionAdapter.sol';
import {CommonLibrary} from '../../../libraries/CommonLibrary.sol';
import {BoolAddress} from '../../../types/BoolAddress.sol';

import {IFluidVaultResolver} from '../../../vendors/fluid/IFluidVaultResolver.sol';
import {IFluidVaultT1} from '../../../vendors/fluid/IFluidVaultT1.sol';

import '../../../libraries/BitMask.sol';
import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';
import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

contract FluidActionAdapter is ILendingActionAdapter {
  using CommonLibrary for address;
  using CalldataDecoder for bytes;
  using TokenHelper for address;

  receive() external payable {}

  function getPosition(
    bytes calldata lendingContext,
    address, // collateralToken
    address, // debtToken
    address // user
  )
    external
    view
    returns (uint256 collateralAmount, uint256 debtAmount)
  {
    (, address resolver,, uint256 nftId) = _decodeLendingContext(lendingContext);

    if (nftId == 0) {
      return (0, 0);
    }

    (IFluidVaultResolver.UserPosition memory userPosition,) =
      IFluidVaultResolver(resolver).positionByNftId(nftId);

    return (userPosition.supply, userPosition.borrow);
  }

  function supplyCollateral(
    bytes calldata lendingContext,
    address collateralToken,
    uint256 supplyAmount,
    address onBehalfOf
  ) external payable {
    (address vault,, bool approvalFlag, uint256 nftId) = _decodeLendingContext(lendingContext);
    _supplyCollateralAndBorrow(
      vault, approvalFlag, nftId, collateralToken, supplyAmount, 0, onBehalfOf
    );
  }

  function withdrawCollateral(
    bytes calldata lendingContext,
    address, // collateralToken
    uint256 withdrawAmount,
    address onBehalfOf
  ) external payable {
    (address vault, address resolver,, uint256 nftId) = _decodeLendingContext(lendingContext);
    _repayAndWithdrawCollateral(
      vault, resolver, false, nftId, address(0), 0, withdrawAmount, onBehalfOf
    );
  }

  function borrow(
    bytes calldata lendingContext,
    address, // debtToken
    uint256 borrowAmount,
    address onBehalfOf
  ) external payable {
    (address vault,,, uint256 nftId) = _decodeLendingContext(lendingContext);
    _supplyCollateralAndBorrow(vault, false, nftId, address(0), 0, borrowAmount, onBehalfOf);
  }

  function repay(
    bytes calldata lendingContext,
    address debtToken,
    uint256 repayAmount,
    address onBehalfOf
  ) external payable {
    (address vault, address resolver, bool approvalFlag, uint256 nftId) =
      _decodeLendingContext(lendingContext);
    _repayAndWithdrawCollateral(
      vault, resolver, approvalFlag, nftId, debtToken, repayAmount, 0, onBehalfOf
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
    (address vault,, bool approvalFlag, uint256 nftId) = _decodeLendingContext(lendingContext);
    _supplyCollateralAndBorrow(
      vault, approvalFlag, nftId, collateralToken, supplyAmount, borrowAmount, onBehalfOf
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
    (address vault, address resolver, bool approvalFlag, uint256 nftId) =
      _decodeLendingContext(lendingContext);
    _repayAndWithdrawCollateral(
      vault, resolver, approvalFlag, nftId, debtToken, repayAmount, withdrawAmount, onBehalfOf
    );
  }

  function _supplyCollateralAndBorrow(
    address vault,
    bool approvalFlag,
    uint256 nftId,
    address collateralToken,
    uint256 supplyAmount,
    uint256 borrowAmount,
    address onBehalfOf
  ) internal {
    uint256 msgValue;

    if (supplyAmount > 0) {
      if (collateralToken.isNative()) {
        msgValue = supplyAmount;
      } else if (approvalFlag) {
        collateralToken.forceApproveInf(vault);
      }
    }

    (nftId,,) = IFluidVaultT1(vault).operate{value: msgValue}(
      nftId, int256(supplyAmount), int256(borrowAmount), address(0)
    );
    if (onBehalfOf != address(this)) {
      address vaultFactory = IFluidVaultT1(vault).VAULT_FACTORY();
      IERC721(vaultFactory).transferFrom(address(this), onBehalfOf, nftId);
    }
  }

  function _repayAndWithdrawCollateral(
    address vault,
    address resolver,
    bool approvalFlag,
    uint256 nftId,
    address debtToken,
    uint256 repayAmount,
    uint256 withdrawAmount,
    address onBehalfOf
  ) internal {
    (IFluidVaultResolver.UserPosition memory userPosition,) =
      IFluidVaultResolver(resolver).positionByNftId(nftId);

    if (repayAmount == type(uint256).max && !debtToken.isNative()) {
      // -type(int256).max
      repayAmount = 1 << 255;
    } else {
      repayAmount = Math.min(repayAmount, userPosition.borrow);
    }

    if (withdrawAmount == type(uint256).max) {
      // -type(int256).max
      withdrawAmount = 1 << 255;
    } else {
      withdrawAmount = Math.min(withdrawAmount, userPosition.supply);
    }

    unchecked {
      if (repayAmount > 0 && !debtToken.isNative() && approvalFlag) {
        debtToken.forceApproveInf(vault);
      }
      (nftId,,) = IFluidVaultT1(vault).operate{value: debtToken.isNative() ? repayAmount : 0}(
        nftId, -int256(withdrawAmount), -int256(repayAmount), address(0)
      );
    }

    if (onBehalfOf != address(this)) {
      address vaultFactory = IFluidVaultT1(vault).VAULT_FACTORY();
      IERC721(vaultFactory).transferFrom(address(this), onBehalfOf, nftId);
    }
  }

  // 0: [1 bit approvalFlag] [160 bits vault or resolver address]
  // 1: [256 bits NFT ID]
  function _decodeLendingContext(bytes calldata lendingContext)
    internal
    pure
    returns (address vault, address resolver, bool approvalFlag, uint256 nftId)
  {
    BoolAddress first = BoolAddress.wrap(lendingContext.decodeUint256());
    vault = first.addressValue();
    resolver = lendingContext.decodeAddress(1);
    approvalFlag = first.boolValue();
    nftId = lendingContext.decodeUint256(2);
  }
}
