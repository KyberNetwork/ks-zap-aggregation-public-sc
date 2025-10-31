// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Params} from '../types/ERC20Params.sol';
import {ERC721Params} from '../types/ERC721Params.sol';
import {ValidateParams} from '../types/ValidateParams.sol';
import {ZapParams} from '../types/ZapParams.sol';

/// @notice Interface for the KS Zap Router V3
interface IKSZapRouterV3 {
  /// @notice Thrown when the deadline is passed
  error DeadlinePassed(uint256 deadline, uint256 blockTimestamp);

  /// @notice Thrown when failed to call the executor
  error CallExecutorFailed();

  /// @notice Thrown when the msg.value is invalid
  error InvalidMsgValue(uint256 expected, uint256 actual);

  /// @notice Thrown when failed to permit using permit2
  error Permit2PermitFailed();

  /// @notice Thrown when failed to transfer from permit2
  error Permit2TransferFromFailed();

  event Zap(
    ERC20Params[] erc20s, ERC721Params[] erc721s, ValidateParams[] validateParams, address executor
  );

  /// @notice Emitted when the client data is set
  event ClientData(bytes clientData);

  /// @notice Entry point for zap action
  function zap(ZapParams calldata zapParams)
    external
    payable
    returns (bytes memory result, uint256 gasUsed);

  /// @notice Returns the address of who called the zap function
  function msgSender() external view returns (address);
}
