// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';

import {ManagementSimple} from 'ks-common-sc/src/base/ManagementSimple.sol';
import {KSRoles} from 'ks-common-sc/src/libraries/KSRoles.sol';
import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';

import {ERC721Holder} from 'openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol';
import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {TransientSlot} from 'openzeppelin-contracts/contracts/utils/TransientSlot.sol';
import {ECDSA} from 'openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';

/**
 * @title AHV2ProxyCallee
 * @notice Callee that calls or delegatecalls a list of whitelisted callees in order, as a single
 * call of an order of the allowance hub
 * @dev Each callee has a `uint256` of call parameters, which holds its flags in the high bits and
 * its native value in the low 128 bits. A delegatecalled callee reads the account it acts for
 * from {ISettlementContext-msgSender} of the hub. A call that this contract receives while a
 * callee is delegatecalled, such as a callback, is delegatecalled to that callee, which must
 * check the caller. {ERC721Holder-onERC721Received} is answered by this contract and is not
 * delegatecalled.
 */
contract AHV2ProxyCallee is IAHV2Callee, ERC721Holder, ManagementSimple {
  using Address for address;
  using CalldataDecoder for bytes;
  using TransientSlot for *;

  /// @notice A call reached the fallback while no callee is delegatecalled
  error NoActiveCallee();

  /// @notice The deadline of the signed solver data has passed
  /// @param deadline The deadline of the signed solver data
  /// @param blockTimestamp The timestamp of the block
  error DeadlinePassed(uint256 deadline, uint256 blockTimestamp);

  /// @notice Role the signer of the solver data must hold on this contract
  bytes32 public constant SIGNER_ROLE = keccak256('SIGNER_ROLE');

  /// @notice Role a callee must hold on this contract
  bytes32 public constant WHITELISTED_CALLEE_ROLE = keccak256('WHITELISTED_CALLEE_ROLE');

  /// @notice Flag of a callee that is called rather than delegatecalled
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
   * @param initialSigners Accounts granted {SIGNER_ROLE}
   */
  constructor(
    address initialAdmin,
    address[] memory initialGuardians,
    address[] memory initialWhitelistedCallees,
    address[] memory initialSigners
  ) ManagementSimple(initialAdmin, initialGuardians) {
    _batchGrantRole(WHITELISTED_CALLEE_ROLE, initialWhitelistedCallees);
    _batchGrantRole(SIGNER_ROLE, initialSigners);
    _setRoleRevoker(WHITELISTED_CALLEE_ROLE, KSRoles.GUARDIAN_ROLE);
  }

  /// @notice Delegatecalls the active callee with the calldata received
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
   * @dev A delegatecalled callee sees the full `msg.value`.
   * @param proxyOwnerData `abi.encode(address[] callees, uint256[] callParams, bytes[] ownerData)`,
   * where `callParams[i]` holds the flags and the value of `callees[i]`
   * @param proxySolverData `abi.encode(bytes[] solverData, uint256 deadline, bytes signature)`,
   * with one element of `solverData` per callee, which may be empty. `signature` is signed by an
   * account holding {SIGNER_ROLE} over `keccak256(abi.encode(block.chainid, address(this),
   * msg.sender, deadline, proxyOwnerData, solverData))`.
   * @return `abi.encode(bytes[] results)`, holding the return data of each callee
   */
  function execute(bytes calldata proxyOwnerData, bytes calldata proxySolverData)
    external
    payable
    whenNotPaused
    returns (bytes memory)
  {
    // Callee `i` receives `execute(ownerData[i], solverData[i])`
    address[] calldata callees = proxyOwnerData.decodeAddressArray(0);
    uint256[] calldata callParams = proxyOwnerData.decodeUint256Array(1);
    bytes[] calldata ownerData = proxyOwnerData.decodeBytesArray(2);
    if (callees.length != callParams.length || callees.length != ownerData.length) {
      revert MismatchedArrayLengths();
    }

    bytes[] calldata solverData = proxySolverData.decodeBytesArray(0);
    if (solverData.length != callees.length) {
      revert MismatchedArrayLengths();
    }

    // The signature is verified before any callee runs
    _verifySignature(
      proxyOwnerData, solverData, proxySolverData.decodeUint256(1), proxySolverData.decodeBytes(2)
    );

    bytes[] memory results = new bytes[](callees.length);
    for (uint256 i = 0; i < callees.length; i++) {
      bytes memory callData = abi.encodeCall(IAHV2Callee.execute, (ownerData[i], solverData[i]));
      results[i] = _execute(callees[i], callParams[i], callData);
    }

    return abi.encode(results);
  }

  /// @dev Calls `callee` with `data` and the value in `callParams`, or delegatecalls it with
  /// `data` when {FLAG_CALL} is not set
  function _execute(address callee, uint256 callParams, bytes memory data)
    internal
    returns (bytes memory result)
  {
    _checkRole(WHITELISTED_CALLEE_ROLE, callee);

    // With {FLAG_CALL}, the value is sent from the native balance of this contract
    if (callParams & FLAG_CALL != 0) {
      // forge-lint: disable-next-line(arbitrary-send-eth)
      return callee.functionCallWithValue(data, callParams & VALUE_MASK);
    }

    // Without the flag, the value is ignored. The callee is the active callee for the duration of
    // the delegatecall, after which the previous active callee is restored.
    TransientSlot.AddressSlot slot = ACTIVE_CALLEE_SLOT.asAddress();
    address previous = slot.tload();
    slot.tstore(callee);
    result = callee.functionDelegateCall(data);
    slot.tstore(previous);
  }

  /// @dev Reverts when the deadline has passed or when the signature over the call data is not
  /// signed by an account holding {SIGNER_ROLE}
  function _verifySignature(
    bytes calldata proxyOwnerData,
    bytes[] calldata solverData,
    uint256 deadline,
    bytes calldata signature
  ) internal view {
    if (deadline < block.timestamp) {
      revert DeadlinePassed(deadline, block.timestamp);
    }

    // The signed hash binds the solver data to the owner data, the deadline, the chain, this
    // contract and the caller
    bytes32 hash = keccak256(
      abi.encode(block.chainid, address(this), msg.sender, deadline, proxyOwnerData, solverData)
    );
    _checkRole(SIGNER_ROLE, ECDSA.recover(hash, signature));
  }
}
