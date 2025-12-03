// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IKSZapExecutor} from './interfaces/IKSZapExecutor.sol';
import {IKSZapRouterV3} from './interfaces/IKSZapRouterV3.sol';

import {ERC20Params} from './types/ERC20Params.sol';
import {ERC721Params} from './types/ERC721Params.sol';

import {ValidateParams} from './types/ValidateParams.sol';
import {ZapParams} from './types/ZapParams.sol';

import {Lock} from 'ks-common-sc/src/base/Lock.sol';
import {ManagementBase} from 'ks-common-sc/src/base/ManagementBase.sol';
import {ManagementPausable} from 'ks-common-sc/src/base/ManagementPausable.sol';
import {ManagementRescuable} from 'ks-common-sc/src/base/ManagementRescuable.sol';
import {IAllowanceTransfer} from 'ks-common-sc/src/interfaces/IAllowanceTransfer.sol';
import {KSRoles} from 'ks-common-sc/src/libraries/KSRoles.sol';
import {PermitHelper} from 'ks-common-sc/src/libraries/token/PermitHelper.sol';

contract KSZapRouterV3 is IKSZapRouterV3, Lock, ManagementPausable, ManagementRescuable {
  IAllowanceTransfer public immutable PERMIT2;

  constructor(
    address initialAdmin,
    address[] memory initialGuardians,
    address[] memory initialRescuers,
    address permit2
  ) ManagementBase(0, initialAdmin) {
    _batchGrantRole(KSRoles.GUARDIAN_ROLE, initialGuardians);
    _batchGrantRole(KSRoles.RESCUER_ROLE, initialRescuers);

    PERMIT2 = IAllowanceTransfer(permit2);
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

    if (zapParams.permit2Data.length > 0) {
      PermitHelper.callPermit2(PERMIT2, msg.sender, zapParams.permit2Data);
    }

    _collectERC20s(zapParams.erc20s);
    _collectERC721s(zapParams.erc721s);

    result = IKSZapExecutor(zapParams.executor).executeZap(zapParams.executorData);

    _afterExecution(zapParams.validateParams, beforeExecutionData);

    emit Zap(zapParams.erc20s, zapParams.erc721s, zapParams.validateParams, zapParams.executor);

    if (zapParams.clientData.length > 0) {
      emit ClientData(zapParams.clientData);
    }

    unchecked {
      gasUsed = gasBefore - gasleft();
    }
  }

  /// @inheritdoc IKSZapRouterV3
  function msgSender() external view returns (address) {
    return _getLocker();
  }

  /// @dev Returns the state before execution
  function _beforeExecution(ValidateParams[] calldata validateParams)
    internal
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
  ) internal {
    for (uint256 i = 0; i < validateParams.length; i++) {
      validateParams[i].afterExecution(beforeExecutionData[i]);
    }
  }

  /// @dev Collects the ERC20 tokens from the sender to the executor
  function _collectERC20s(ERC20Params[] calldata erc20s) internal {
    for (uint256 i = 0; i < erc20s.length; i++) {
      erc20s[i].collect(PERMIT2);
    }
  }

  /// @dev Collects the ERC721 tokens from the sender to the executor
  function _collectERC721s(ERC721Params[] calldata erc721s) internal {
    for (uint256 i = 0; i < erc721s.length; i++) {
      erc721s[i].collect();
    }
  }
}
