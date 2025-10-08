// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IKSZapExecutor} from './interfaces/IKSZapExecutor.sol';
import {IKSZapRouterV3} from './interfaces/IKSZapRouterV3.sol';

import {ERC20Params} from './types/ERC20Params.sol';
import {ERC721Params} from './types/ERC721Params.sol';

import {ValidateParams} from './types/ValidateParams.sol';
import {ZapParams} from './types/ZapParams.sol';

import {IAllowanceTransfer} from 'ks-common-sc/src/interfaces/IAllowanceTransfer.sol';

import {Lock} from 'ks-common-sc/src/base/Lock.sol';
import {ManagementBase} from 'ks-common-sc/src/base/ManagementBase.sol';
import {ManagementPausable} from 'ks-common-sc/src/base/ManagementPausable.sol';
import {ManagementRescuable} from 'ks-common-sc/src/base/ManagementRescuable.sol';

import {KSRoles} from 'ks-common-sc/src/libraries/KSRoles.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

contract KSZapRouterV3 is IKSZapRouterV3, Lock, ManagementPausable, ManagementRescuable {
  using Address for address;

  address public immutable PERMIT2;

  // keccak256('permit(address,((address,uint160,uint48,uint48)[],address,uint256),bytes)')
  bytes4 constant PERMIT2_PERMIT_SELECTOR = 0x2a2d80d1;

  constructor(
    address initialAdmin,
    address[] memory initialGuardians,
    address[] memory initialRescuers,
    address permit2
  ) ManagementBase(0, initialAdmin) {
    _batchGrantRole(KSRoles.GUARDIAN_ROLE, initialGuardians);
    _batchGrantRole(KSRoles.RESCUER_ROLE, initialRescuers);

    PERMIT2 = permit2;
  }

  /// @inheritdoc IKSZapRouterV3
  function zap(ZapParams calldata zapParams)
    external
    payable
    whenNotPaused
    returns (bytes memory result, uint256 gasUsed)
  {
    uint256 gasBefore = gasleft();

    bytes[] memory beforeExecutionData = _beforeExecution(zapParams.validateParams);

    bool[] memory usePermit2 = _collectERC20s(zapParams.erc20s, zapParams.executor);
    _collectERC721s(zapParams.erc721s, zapParams.executor);

    if (zapParams.permit2Data.length > 0) {
      PERMIT2.functionCall(abi.encodePacked(PERMIT2_PERMIT_SELECTOR, zapParams.permit2Data));
    }

    _permit2TransferFrom(zapParams.erc20s, usePermit2, zapParams.executor);

    result = IKSZapExecutor(zapParams.executor).executeZap{value: msg.value}(zapParams.executorData);

    _afterExecution(zapParams.validateParams, beforeExecutionData);

    emit Zap(zapParams.erc20s, zapParams.erc721s, zapParams.validateParams, zapParams.executor);

    if (zapParams.clientData.length > 0) {
      emit ClientData(zapParams.clientData);
    }

    gasUsed = gasBefore - gasleft();
  }

  /// @inheritdoc IKSZapRouterV3
  function msgSender() external view returns (address) {
    return _getLocker();
  }

  /// @dev Transfers the ERC20 tokens from the sender to the executor using permit2
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

      IAllowanceTransfer(PERMIT2).transferFrom(details);
    }
  }

  /// @dev Returns the state before execution
  function _beforeExecution(ValidateParams[] calldata validateParams)
    internal
    view
    returns (bytes[] memory)
  {
    bytes[] memory beforeExecutionData = new bytes[](validateParams.length);
    for (uint256 i = 0; i < validateParams.length; i++) {
      beforeExecutionData[i] = validateParams[i].beforeExecution();
    }

    return beforeExecutionData;
  }

  /// @dev Validates the current state after execution against the before execution state
  function _afterExecution(
    ValidateParams[] calldata validateParams,
    bytes[] memory beforeExecutionData
  ) internal view {
    for (uint256 i = 0; i < validateParams.length; i++) {
      validateParams[i].afterExecution(beforeExecutionData[i]);
    }
  }

  /// @dev Collects the ERC20 tokens from the sender to the executor
  function _collectERC20s(ERC20Params[] calldata erc20s, address executor)
    internal
    returns (bool[] memory usePermit2)
  {
    usePermit2 = new bool[](erc20s.length);
    for (uint256 i = 0; i < erc20s.length; i++) {
      usePermit2[i] = erc20s[i].collect(executor);
    }
  }

  /// @dev Collects the ERC721 tokens from the sender to the executor
  function _collectERC721s(ERC721Params[] calldata erc721s, address executor) internal {
    for (uint256 i = 0; i < erc721s.length; i++) {
      erc721s[i].collect(executor);
    }
  }
}
