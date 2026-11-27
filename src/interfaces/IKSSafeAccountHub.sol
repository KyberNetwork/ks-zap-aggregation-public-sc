// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

  /// @notice Thrown when the caller of {execute} is not the flash loan adapter
  error UnauthorizedCaller(address caller);

  /// @notice Thrown when {execute} runs for a Safe Account that it already ran for in the
  /// transaction
  error SafeAlreadyExecuted(address safe);

  /// @notice Thrown when the token is transferred during the settlement of an order of the
  /// allowance hub, and neither the sender nor the receiver is this contract
  error TransferDuringSettlement(address from, address to);

  /**
   * @notice Makes the Safe Account delegatecall `target` with `data` as a module transaction of
   * this contract, then transfers its token
   * @dev Only the flash loan adapter may call it. It is refused while it is executing, for a Safe
   * Account it already ran for in the transaction, and when this contract does not hold the token.
   * @param safe The Safe Account
   * @param target The contract the Safe Account delegatecalls
   * @param data The calldata of the delegatecall
   * @param owner The account that receives the token of the Safe Account
   * @return returnData The return data of the delegatecall
   */
  function execute(address safe, address target, bytes calldata data, address owner)
    external
    returns (bytes memory returnData);

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
}
