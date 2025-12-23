// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IKSZapExecutor} from './interfaces/IKSZapExecutor.sol';
import {IKSZapRouterV3} from './interfaces/IKSZapRouterV3.sol';
import {IKSGenericRouter} from 'ks-allowance-hub/src/interfaces/IKSGenericRouter.sol';

import {ValidateParams} from './types/ValidateParams.sol';
import {ZapParams} from './types/ZapParams.sol';

import {Lock} from 'ks-common-sc/src/base/Lock.sol';
import {ManagementBase} from 'ks-common-sc/src/base/ManagementBase.sol';
import {ManagementPausable} from 'ks-common-sc/src/base/ManagementPausable.sol';
import {ManagementRescuable} from 'ks-common-sc/src/base/ManagementRescuable.sol';
import {KSRoles} from 'ks-common-sc/src/libraries/KSRoles.sol';
import {PermitHelper} from 'ks-common-sc/src/libraries/token/PermitHelper.sol';

contract KSZapRouterV3 is
  IKSZapRouterV3,
  IKSGenericRouter,
  Lock,
  ManagementPausable,
  ManagementRescuable
{
  /// @notice Role for the whitelisted approval proxies.
  bytes32 internal constant ALLOWANCE_HUB_ROLE = keccak256('ALLOWANCE_HUB_ROLE');

  constructor(
    address initialAdmin,
    address[] memory initialGuardians,
    address[] memory initialRescuers,
    address[] memory initialAllowanceHubs
  ) ManagementBase(0, initialAdmin) {
    _batchGrantRole(KSRoles.GUARDIAN_ROLE, initialGuardians);
    _batchGrantRole(KSRoles.RESCUER_ROLE, initialRescuers);
    _batchGrantRole(ALLOWANCE_HUB_ROLE, initialAllowanceHubs);
  }

  /**
   * @notice Called by the allowance hub to swap and then bridge the tokens.
   * @param data The encoded data of `ZapParams` struct.
   */
  function ksExecute(bytes calldata data)
    external
    payable
    whenNotPaused
    onlyRole(ALLOWANCE_HUB_ROLE)
    returns (bytes memory result)
  {
    ZapParams calldata zapParams;
    assembly ('memory-safe') {
      zapParams := add(data.offset, calldataload(data.offset))
    }

    bytes[] memory beforeExecutionData = _beforeExecution(zapParams.validateParams);

    result = IKSZapExecutor(zapParams.executor).executeZap{value: msg.value}(zapParams.executorData);

    _afterExecution(zapParams.validateParams, beforeExecutionData);

    emit Zap(zapParams.validateParams, zapParams.executor);

    if (zapParams.clientData.length > 0) {
      emit ClientData(zapParams.clientData);
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
}
