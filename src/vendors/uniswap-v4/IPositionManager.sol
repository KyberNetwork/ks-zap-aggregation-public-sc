// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from './IPoolManager.sol';
import {PoolKey} from './PoolKey.sol';
import {PositionInfo} from './PositionInfoLibrary.sol';

import {IAllowanceTransfer} from 'ks-common-sc/src/interfaces/IAllowanceTransfer.sol';

import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';

/// @title IImmutableState
/// @notice Interface for the ImmutableState contract
interface IImmutableState {
  /// @notice The Uniswap v4 PoolManager contract
  function poolManager() external view returns (IPoolManager);
}

/// @title IPositionManager
/// @notice Interface for the PositionManager contract
interface IPositionManager is IImmutableState, IERC721 {
  /// @notice Thrown when the caller is not approved to modify a position
  error NotApproved(address caller);
  /// @notice Thrown when the block.timestamp exceeds the user-provided deadline
  error DeadlinePassed(uint256 deadline);
  /// @notice Thrown when calling transfer, subscribe, or unsubscribe when the PoolManager is unlocked.
  /// @dev This is to prevent hooks from being able to trigger notifications at the same time the position is being modified.
  error PoolManagerMustBeLocked();

  /// @notice Unlocks Uniswap v4 PoolManager and batches actions for modifying liquidity
  /// @dev This is the standard entrypoint for the PositionManager
  /// @param unlockData is an encoding of actions, and parameters for those actions
  /// @param deadline is the deadline for the batched actions to be executed
  function modifyLiquidities(bytes calldata unlockData, uint256 deadline) external payable;

  /// @notice Batches actions for modifying liquidity without unlocking v4 PoolManager
  /// @dev This must be called by a contract that has already unlocked the v4 PoolManager
  /// @param actions the actions to perform
  /// @param params the parameters to provide for the actions
  function modifyLiquiditiesWithoutUnlock(bytes calldata actions, bytes[] calldata params)
    external
    payable;

  /// @notice Used to get the ID that will be used for the next minted liquidity position
  /// @return uint256 The next token ID
  function nextTokenId() external view returns (uint256);

  /// @param tokenId the ERC721 tokenId
  /// @return liquidity the position's liquidity, as a liquidityAmount
  /// @dev this value can be processed as an amount0 and amount1 by using the LiquidityAmounts library
  function getPositionLiquidity(uint256 tokenId) external view returns (uint128 liquidity);

  /// @param tokenId the ERC721 tokenId
  /// @return PositionInfo a uint256 packed value holding information about the position including the range (tickLower, tickUpper)
  /// @return poolKey the pool key of the position
  function getPoolAndPositionInfo(uint256 tokenId)
    external
    view
    returns (PoolKey memory, PositionInfo);

  function permit2() external view returns (IAllowanceTransfer);

  function poolKeys(bytes25 poolId) external view returns (PoolKey memory);
}
