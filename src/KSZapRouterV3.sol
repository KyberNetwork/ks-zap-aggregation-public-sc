// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapExecutor} from './interfaces/IKSZapExecutor.sol';
import {IKSZapRouterV3} from './interfaces/IKSZapRouterV3.sol';

import {ERC20Params} from './types/ERC20Params.sol';
import {ERC721Params} from './types/ERC721Params.sol';
import {ZapParams} from './types/ZapParams.sol';

import {IAllowanceTransfer} from 'ks-common-sc/src/interfaces/IAllowanceTransfer.sol';

import {Lock} from 'ks-common-sc/src/base/Lock.sol';
import {ManagementBase} from 'ks-common-sc/src/base/ManagementBase.sol';
import {ManagementPausable} from 'ks-common-sc/src/base/ManagementPausable.sol';
import {ManagementRescuable} from 'ks-common-sc/src/base/ManagementRescuable.sol';

import {CustomRevert} from 'ks-common-sc/src/libraries/CustomRevert.sol';

contract KSZapRouterV3 is IKSZapRouterV3, Lock, ManagementPausable, ManagementRescuable {
  address public immutable PERMIT2;

  constructor(address initialAdmin, address permit2) ManagementBase(0, initialAdmin) {
    PERMIT2 = permit2;
  }

  /// @inheritdoc IKSZapRouterV3
  function zap(ZapParams calldata zapParams)
    external
    returns (bytes memory result, uint256 gasUsed)
  {
    uint256 gasBefore = gasleft();

    bytes[] memory beforeExecutionData = new bytes[](zapParams.validateParams.length);
    for (uint256 i = 0; i < zapParams.validateParams.length; i++) {
      beforeExecutionData[i] = zapParams.validateParams[i].beforeExecution();
    }

    bool[] memory usePermit2 = _collectERC20s(zapParams.erc20s, zapParams.executor);
    _collectERC721s(zapParams.erc721s);

    _permit2Permit(zapParams.permit2Data);
    _permit2TransferFrom(zapParams.erc20s, usePermit2, zapParams.executor);

    result = _callExecutor(zapParams.executor, zapParams.executorData);

    for (uint256 i = 0; i < zapParams.validateParams.length; i++) {
      zapParams.validateParams[i].afterExecution(beforeExecutionData[i]);
    }

    emit Zap(zapParams.erc20s, zapParams.erc721s, zapParams.validateParams, zapParams.executor);

    emit ClientData(zapParams.clientData);

    gasUsed = gasBefore - gasleft();
  }

  /// @inheritdoc IKSZapRouterV3
  function msgSender() external view returns (address) {
    return _getLocker();
  }

  function _permit2Permit(bytes calldata permit2Data) internal {
    if (permit2Data.length > 0) {
      (bool success,) =
        PERMIT2.call(abi.encodePacked(IAllowanceTransfer.permit.selector, permit2Data));
      if (!success) {
        CustomRevert.bubbleUpAndRevertWith(
          PERMIT2, IAllowanceTransfer.permit.selector, Permit2PermitFailed.selector
        );
      }
    }
  }

  function _permit2TransferFrom(
    ERC20Params[] calldata erc20s,
    bool[] memory usePermit2,
    address executor
  ) internal {
    IAllowanceTransfer.AllowanceTransferDetails[] memory details =
      new IAllowanceTransfer.AllowanceTransferDetails[](erc20s.length);
    uint256 detailsLength = 0;

    for (uint256 i = 0; i < erc20s.length; i++) {
      if (usePermit2[i]) {
        details[detailsLength++] = IAllowanceTransfer.AllowanceTransferDetails({
          from: msg.sender,
          to: executor,
          amount: uint160(erc20s[i].amount),
          token: erc20s[i].token
        });
      }
    }

    if (detailsLength > 0) {
      // Set the correct length of the details array
      assembly ("memory-safe") {
        mstore(details, detailsLength)
      }

      (bool success,) = PERMIT2.call(abi.encodeCall(IAllowanceTransfer.transferFrom, details));
      if (!success) {
        CustomRevert.bubbleUpAndRevertWith(
          PERMIT2, IAllowanceTransfer.transferFrom.selector, Permit2TransferFromFailed.selector
        );
      }
    }
  }

  function _collectERC20s(ERC20Params[] calldata erc20s, address executor)
    internal
    returns (bool[] memory usePermit2)
  {
    usePermit2 = new bool[](erc20s.length);
    for (uint256 i = 0; i < erc20s.length; i++) {
      usePermit2[i] = erc20s[i].collect(executor);
    }
  }

  function _collectERC721s(ERC721Params[] calldata erc721s) internal {
    for (uint256 i = 0; i < erc721s.length; i++) {
      erc721s[i].collect(msg.sender);
    }
  }

  function _callExecutor(address executor, bytes calldata executorData)
    internal
    returns (bytes memory result)
  {
    bool success;
    (success, result) =
      executor.call{value: msg.value}(abi.encodeCall(IKSZapExecutor.executeZap, executorData));
    if (!success) {
      CustomRevert.bubbleUpAndRevertWith(
        executor, IKSZapExecutor.executeZap.selector, CallExecutorFailed.selector
      );
    }
  }
}
