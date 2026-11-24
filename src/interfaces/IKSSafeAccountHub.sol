// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ContractCall} from '../types/ContractCall.sol';
import {ISafe} from '../vendors/safe-smart-account/ISafe.sol';

import {IUnorderedNonce} from './IUnorderedNonce.sol';
import {IERC721Permit_v4} from 'ks-common-sc/src/interfaces/IERC721Permit_v4.sol';
import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';

/// @title IKSSafeAccountHub
/// @notice Interface of {KSSafeAccountHub}
interface IKSSafeAccountHub is IERC721Permit_v4, IUnorderedNonce, IERC721 {
  /// @notice Thrown when the Safe Account is not authorized
  error UnauthorizedSafe();

  /// @notice Thrown when the execution fails
  error SafeModuleExecutionFailed(bytes reason);

  /// @notice Thrown when enabling the module fails
  error EnableModuleFailed();

  /// @notice Thrown when disabling the module fails
  error DisableModuleFailed();

  /// @notice Thrown when the caller of {execute} is not the leverage adapter
  error UnauthorizedCaller(address caller);

  /// @notice Thrown when {execute} runs for a Safe Account that it already ran for in the
  /// transaction
  error SafeAlreadyExecuted(address safe);

  /// @notice Thrown when the token is transferred during the settlement of an order of the
  /// allowance hub, and neither the sender nor the receiver is this contract
  error TransferDuringSettlement(address from, address to);

  /// @notice Emitted when a Safe Account is registered
  event CreateSafe(address indexed safe, address indexed owner, uint256 indexed tokenId);

  /// @notice Register a Safe Account
  function createSafe(address owner, uint256 saltNonce) external returns (address safe);

  /// @notice Get the next token ID
  function nextTokenId() external view returns (uint256);

  /// @notice Get the token ID for a Safe Account
  function safeToTokenId(address safe) external view returns (uint256);

  /// @notice Get the Safe Account for a token ID
  function tokenIdToSafe(uint256 tokenId) external view returns (address);

  /// @notice Returns the allowance hub whose settlement restricts the transfers of the token
  function ALLOWANCE_HUB() external view returns (address);

  /// @notice Returns the leverage adapter, the only account allowed to call {execute}
  function LEVERAGE_ADAPTER() external view returns (address);

  /**
   * @notice Runs calls from a Safe Account whose token this contract holds, then transfers the
   * token to `owner`
   * @dev Called by the leverage adapter. Refused when called again while it is executing, and for a
   * Safe Account it already ran for in the transaction.
   * @param safe The Safe Account
   * @param modules The modules enabled on the Safe Account during the calls and disabled after them
   * @param calls The calls the Safe Account runs as a module transaction of this contract
   * @param owner The recipient of the token of the Safe Account
   * @return returnData The return data of each call
   */
  function execute(
    address safe,
    address[] calldata modules,
    ContractCall[] calldata calls,
    address owner
  ) external returns (bytes[] memory returnData);
}
