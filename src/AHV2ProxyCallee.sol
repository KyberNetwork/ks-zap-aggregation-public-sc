// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';

import {ManagementSimple} from 'ks-common-sc/src/base/ManagementSimple.sol';
import {KSRoles} from 'ks-common-sc/src/libraries/KSRoles.sol';
import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';

import {ERC721Holder} from 'openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol';
import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {TransientSlot} from 'openzeppelin-contracts/contracts/utils/TransientSlot.sol';

/**
 * @title AHV2ProxyCallee
 * @notice Callee that calls or delegatecalls a list of whitelisted callees in order, as one call
 * of an order of the allowance hub
 * @dev Each callee has a `uint256` of call parameters holding its flags in the high bits and its
 * native value in the low 128 bits. {FLAG_CALL} calls the callee with the value, sent from the
 * balance of this contract, instead of delegatecalling it. The value of a delegatecalled callee is
 * ignored. Every callee is invoked through {IAHV2Callee-execute}. A delegatecalled callee reads
 * the account it acts for from the hub's {ISettlementContext-msgSender}. A call this contract
 * receives while a callee is delegatecalled, such as a callback, is delegatecalled to that callee,
 * which must check who made it. {ERC721Holder-onERC721Received} is answered by this
 * contract and is not delegatecalled.
 */
contract AHV2ProxyCallee is IAHV2Callee, ERC721Holder, ManagementSimple {
  using Address for address;
  using CalldataDecoder for bytes;
  using TransientSlot for *;

  /// @notice A call reached the fallback while no callee is being delegatecalled
  error NoActiveCallee();

  /// @notice Role a callee must hold on this contract
  bytes32 public constant WHITELISTED_CALLEE_ROLE = keccak256('WHITELISTED_CALLEE_ROLE');

  /// @notice Flag of a callee that is called instead of delegatecalled
  uint256 public constant FLAG_CALL = 1 << 255;

  /// @notice Mask of the native value in the call parameters of a callee
  uint256 public constant VALUE_MASK = type(uint128).max;

  /// @dev Transient slot holding the callee being delegatecalled
  bytes32 internal constant ACTIVE_CALLEE_SLOT =
    bytes32(erc7201('ks.zap.proxy-callee.active-callee'));

  /**
   * @dev Guardians may revoke a callee from {WHITELISTED_CALLEE_ROLE} without the admin.
   * @param initialAdmin Account granted the default admin role
   * @param initialGuardians Accounts granted the guardian role
   * @param initialWhitelistedCallees Callees granted {WHITELISTED_CALLEE_ROLE}
   */
  constructor(
    address initialAdmin,
    address[] memory initialGuardians,
    address[] memory initialWhitelistedCallees
  ) ManagementSimple(initialAdmin, initialGuardians) {
    _batchGrantRole(WHITELISTED_CALLEE_ROLE, initialWhitelistedCallees);
    _setRoleRevoker(WHITELISTED_CALLEE_ROLE, KSRoles.GUARDIAN_ROLE);
  }

  /// @notice Delegatecalls the callee being delegatecalled with the same calldata
  fallback() external payable {
    address callee = ACTIVE_CALLEE_SLOT.asAddress().tload();
    if (callee == address(0)) {
      revert NoActiveCallee();
    }

    assembly {
      calldatacopy(0, 0, calldatasize())
      let success := delegatecall(gas(), callee, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      if success {
        return(0, returndatasize())
      }
      revert(0, returndatasize())
    }
  }

  /// @notice Accepts native value
  receive() external payable {}

  /**
   * @inheritdoc IAHV2Callee
   * @dev Each callee receives `execute(ownerData[i], solverData[i])`, with empty solver data when
   * `proxySolverData` is empty. A delegatecalled callee sees the full `msg.value`.
   * @param proxyOwnerData `abi.encode(address[] callees, uint256[] callParams, bytes[] ownerData)`,
   * where each element of `callParams` holds the flags and the value of the callee at the same
   * index
   * @param proxySolverData Empty, or `abi.encode(bytes[] solverData)` with one element per callee
   * @return `abi.encode(bytes[] results)`, holding the return data of each call
   */
  function execute(bytes calldata proxyOwnerData, bytes calldata proxySolverData)
    external
    payable
    whenNotPaused
    returns (bytes memory)
  {
    address[] calldata callees = proxyOwnerData.decodeAddressArray(0);
    uint256[] calldata callParams = proxyOwnerData.decodeUint256Array(1);
    bytes[] calldata ownerData = proxyOwnerData.decodeBytesArray(2);
    if (callees.length != callParams.length || callees.length != ownerData.length) {
      revert MismatchedArrayLengths();
    }

    bytes[] calldata solverData = _decodeSolverData(proxySolverData);
    if (proxySolverData.length != 0 && solverData.length != callees.length) {
      revert MismatchedArrayLengths();
    }

    bytes[] memory results = new bytes[](callees.length);
    for (uint256 i = 0; i < callees.length; i++) {
      bytes calldata calleeSolverData =
        proxySolverData.length == 0 ? proxySolverData : solverData[i];
      bytes memory callData = abi.encodeCall(IAHV2Callee.execute, (ownerData[i], calleeSolverData));
      results[i] = _execute(callees[i], callParams[i], callData);
    }

    return abi.encode(results);
  }

  /// @dev Calls `callee` with `data` and the value in `callParams`, or delegatecalls it with
  /// `data`. A delegatecalled callee is recorded as the active callee, and the previous one is
  /// restored afterwards.
  function _execute(address callee, uint256 callParams, bytes memory data)
    internal
    returns (bytes memory result)
  {
    _checkRole(WHITELISTED_CALLEE_ROLE, callee);

    if (callParams & FLAG_CALL != 0) {
      // forge-lint: disable-next-line(arbitrary-send-eth)
      return callee.functionCallWithValue(data, callParams & VALUE_MASK);
    }

    TransientSlot.AddressSlot slot = ACTIVE_CALLEE_SLOT.asAddress();
    address previous = slot.tload();
    slot.tstore(callee);
    result = callee.functionDelegateCall(data);
    slot.tstore(previous);
  }

  /// @dev Decodes `proxySolverData` as `abi.encode(bytes[] solverData)`, or returns an empty array
  /// when it is empty
  function _decodeSolverData(bytes calldata proxySolverData)
    internal
    pure
    returns (bytes[] calldata solverData)
  {
    if (proxySolverData.length != 0) {
      return proxySolverData.decodeBytesArray(0);
    }
    assembly ('memory-safe') {
      solverData.length := 0
      solverData.offset := proxySolverData.offset
    }
  }
}
