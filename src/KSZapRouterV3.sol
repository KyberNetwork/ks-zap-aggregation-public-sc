// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IKSZapExecutor} from './interfaces/IKSZapExecutor.sol';
import {IKSZapRouterV3} from './interfaces/IKSZapRouterV3.sol';

import {ValidateParams} from './types/ValidateParams.sol';
import {ZapParams} from './types/ZapParams.sol';

import {Lock} from 'ks-common-sc/src/base/Lock.sol';
import {ManagementBase} from 'ks-common-sc/src/base/ManagementBase.sol';
import {ManagementPausable} from 'ks-common-sc/src/base/ManagementPausable.sol';
import {ManagementRescuable} from 'ks-common-sc/src/base/ManagementRescuable.sol';

import {KSRoles} from 'ks-common-sc/src/libraries/KSRoles.sol';
import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';

import {ERC721Holder} from 'openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol';
import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {TransientSlot} from 'openzeppelin-contracts/contracts/utils/TransientSlot.sol';
import {ECDSA} from 'openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';

contract KSZapRouterV3 is
  IKSZapRouterV3,
  Lock,
  ManagementPausable,
  ManagementRescuable,
  ERC721Holder
{
  using CalldataDecoder for bytes;
  using Address for address;
  using TransientSlot for *;

  /// @notice Role for the call data signers.
  bytes32 internal constant SIGNER_ROLE = keccak256('SIGNER_ROLE');

  /// @notice The slot holding the executor address, transiently.
  bytes32 internal constant EXECUTOR_SLOT = bytes32(uint256(keccak256('Executor')) - 1);

  constructor(
    address initialAdmin,
    address[] memory initialGuardians,
    address[] memory initialRescuers,
    address[] memory initialSigners
  )
    ManagementBase(0, initialAdmin)
    ManagementPausable(initialGuardians)
    ManagementRescuable(initialRescuers)
  {
    _batchGrantRole(SIGNER_ROLE, initialSigners);
  }

  /// @dev Allows the contract to receive native tokens
  receive() external payable {}

  /// @dev Forwards the call to the current executor
  fallback(bytes calldata data) external payable returns (bytes memory) {
    return EXECUTOR_SLOT.asAddress().tload().functionDelegateCall(data);
  }

  /// @inheritdoc IKSZapRouterV3
  function ksExecute(bytes calldata data)
    external
    payable
    whenNotPaused
    isNotLocked
    returns (bytes memory result)
  {
    ZapParams calldata zapParams;
    assembly ('memory-safe') {
      zapParams := add(data.offset, calldataload(data.offset))
    }

    // Set the executor address in transient storage
    EXECUTOR_SLOT.asAddress().tstore(zapParams.executor);

    if (zapParams.deadline < block.timestamp) {
      revert DeadlinePassed(zapParams.deadline, block.timestamp);
    }

    bytes calldata signature = data.decodeBytes(1);
    _verifySignature(zapParams, signature);

    bytes[] memory beforeExecutionData = _beforeExecution(zapParams.validateParams);

    result = zapParams.executor
      .functionDelegateCall(abi.encodeCall(IKSZapExecutor.executeZap, (zapParams.executorData)));

    _afterExecution(zapParams.validateParams, beforeExecutionData);

    emit Zap(zapParams.validateParams, zapParams.executor);

    if (zapParams.clientData.length > 0) {
      emit ClientData(zapParams.clientData);
    }

    // Clear the executor address from transient storage
    EXECUTOR_SLOT.asAddress().tstore(address(0));
  }

  /// @inheritdoc IKSZapRouterV3
  function msgSender() external view returns (address) {
    return _getLocker();
  }

  function _verifySignature(ZapParams calldata zapParams, bytes calldata signature) internal view {
    bytes32 hash = keccak256(abi.encode(block.chainid, address(this), msg.sender, zapParams));
    _checkRole(SIGNER_ROLE, ECDSA.recover(hash, signature));
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
