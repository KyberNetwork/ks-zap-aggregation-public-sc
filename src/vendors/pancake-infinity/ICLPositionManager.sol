//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BalanceDelta} from './BalanceDelta.sol';
import {CLPositionInfo} from './CLPositionInfoLibrary.sol';
import {ICLPoolManager} from './ICLPoolManager.sol';
import {IVault} from './IVault.sol';
import {PoolKey} from './PoolKey.sol';

import {IAllowanceTransfer} from 'ks-common-sc/src/interfaces/IAllowanceTransfer.sol';

import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';

/// @title IImmutableState
/// @notice Interface for the ImmutableState contract
interface IImmutableState {
  /// @notice The Pancakeswap Infinity Vault contract
  function vault() external view returns (IVault);
}

/// @title IPositionManager
/// @notice Interface for the PositionManager contract
interface IPositionManager is IImmutableState {
  /// @notice Thrown when the block.timestamp exceeds the user-provided deadline
  error DeadlinePassed(uint256 deadline);

  /// @notice Thrown when calling transfer, subscribe, or unsubscribe on CLPositionManager
  /// or batchTransferFrom on BinPositionManager when the vault is locked.
  /// @dev This is to prevent hooks from being able to trigger actions or notifications at the same time the position is being modified.
  error VaultMustBeUnlocked();

  /// @notice Thrown when the token ID is bind to an unexisting pool
  error InvalidTokenID();

  /// @notice Unlocks Vault and batches actions for modifying liquidity
  /// @dev This is the standard entrypoint for the PositionManager
  /// @param payload is an encoding of actions, and parameters for those actions
  /// @param deadline is the deadline for the batched actions to be executed
  function modifyLiquidities(bytes calldata payload, uint256 deadline) external payable;

  /// @notice Batches actions for modifying liquidity without getting a lock from vault
  /// @dev This must be called by a contract that has already locked the vault
  /// @param actions the actions to perform
  /// @param params the parameters to provide for the actions
  function modifyLiquiditiesWithoutLock(bytes calldata actions, bytes[] calldata params)
    external
    payable;
}

interface ICLPositionManager is IPositionManager, IERC721 {
  /// @notice Thrown when the caller is not approved to modify a position
  error NotApproved(address caller);

  /// @notice Emitted when a new liquidity position is minted
  event MintPosition(uint256 indexed tokenId);

  /// @notice Emitted when liquidity is modified
  /// @param tokenId the tokenId of the position that was modified
  /// @param liquidityChange the change in liquidity of the position
  /// @param feesAccrued the fees collected from the liquidity change
  event ModifyLiquidity(uint256 indexed tokenId, int256 liquidityChange, BalanceDelta feesAccrued);

  /// @notice Get the clPoolManager
  function clPoolManager() external view returns (ICLPoolManager);

  /// @notice Initialize an infinity cl pool
  /// @dev If the pool is already initialized, this function will not revert and just return type(int24).max
  /// @param key the PoolKey of the pool to initialize
  /// @param sqrtPriceX96 the initial sqrtPriceX96 of the pool
  /// @return tick The current tick of the pool
  function initializePool(PoolKey calldata key, uint160 sqrtPriceX96)
    external
    payable
    returns (int24);

  /// @notice Used to get the ID that will be used for the next minted liquidity position
  /// @return uint256 The next token ID
  function nextTokenId() external view returns (uint256);

  /// @param tokenId the ERC721 tokenId
  /// @return liquidity the position's liquidity, as a liquidityAmount
  /// @dev this value can be processed as an amount0 and amount1 by using the LiquidityAmounts library
  function getPositionLiquidity(uint256 tokenId) external view returns (uint128 liquidity);

  /// @notice Get the detailed information for a specified position
  /// @param tokenId the ERC721 tokenId
  /// @return poolKey the pool key of the position
  /// @return tickLower the lower tick of the position
  /// @return tickUpper the upper tick of the position
  /// @return liquidity the liquidity of the position
  /// @return feeGrowthInside0LastX128 the fee growth count of token0 since last time updated
  /// @return feeGrowthInside1LastX128 the fee growth count of token1 since last time updated
  /// @return _subscriber the address of the subscriber, if not set, it returns address(0)
  function positions(uint256 tokenId)
    external
    view
    returns (
      PoolKey memory poolKey,
      int24 tickLower,
      int24 tickUpper,
      uint128 liquidity,
      uint256 feeGrowthInside0LastX128,
      uint256 feeGrowthInside1LastX128,
      address _subscriber
    );

  /// @param tokenId the ERC721 tokenId
  /// @return poolKey the pool key of the position
  /// @return CLPositionInfo a uint256 packed value holding information about the position including the range (tickLower, tickUpper)
  function getPoolAndPositionInfo(uint256 tokenId)
    external
    view
    returns (PoolKey memory, CLPositionInfo);

  function permit2() external view returns (IAllowanceTransfer);

  function poolKeys(bytes25 poolId) external view returns (PoolKey memory);
}
