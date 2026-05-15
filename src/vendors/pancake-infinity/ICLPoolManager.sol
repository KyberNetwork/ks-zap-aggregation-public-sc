//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BalanceDelta} from './BalanceDelta.sol';
import {IVault} from './IVault.sol';
import {PoolKey} from './PoolKey.sol';
import {ModifyLiquidityParams, SwapParams} from './PoolOperation.sol';
import {Tick} from './Tick.sol';

interface ICLPoolManager {
  /// @notice Thrown when trying to interact with a non-initialized pool
  error PoolNotInitialized();

  /// @notice PoolKey must have currencies where address(currency0) < address(currency1)
  error CurrenciesInitializedOutOfOrder(address currency0, address currency1);

  /// @notice Thrown when a call to updateDynamicLPFee is made by an address that is not the hook,
  /// or on a pool is not a dynamic fee pool.
  error UnauthorizedDynamicLPFeeUpdate();

  /// @notice Emitted when lp fee is updated
  /// @dev The event is emitted even if the updated fee value is the same as previous one
  event DynamicLPFeeUpdated(bytes32 indexed id, uint24 dynamicLPFee);

  /// @notice Returns the vault where the protocol fees are safely stored
  /// @return IVault The address of the vault
  function vault() external view returns (IVault);

  /// @notice Updates lp fee for a dyanmic fee pool
  /// @dev Some of the use case could be:
  ///   1) when hook#beforeSwap() is called and hook call this function to update the lp fee
  ///   2) For BinPool only, when hook#beforeMint() is called and hook call this function to update the lp fee
  ///   3) other use case where the hook might want to on an ad-hoc basis increase/reduce lp fee
  function updateDynamicLPFee(PoolKey memory key, uint24 newDynamicLPFee) external;

  /// @notice Return PoolKey for a given bytes32
  function poolIdToPoolKey(bytes32 id) external view returns (PoolKey memory key);

  /// @notice PoolManagerMismatch is thrown when pool manager specified in the pool key does not match current contract
  error PoolManagerMismatch();
  /// @notice Pools are limited to type(int16).max tickSpacing in #initialize, to prevent overflow
  error TickSpacingTooLarge(int24 tickSpacing);
  /// @notice Pools must have a positive non-zero tickSpacing passed to #initialize
  error TickSpacingTooSmall(int24 tickSpacing);
  /// @notice Error thrown when add liquidity is called when paused()
  error PoolPaused();
  /// @notice Thrown when trying to swap amount of 0
  error SwapAmountCannotBeZero();

  /// @notice Emitted when a liquidity position is modified
  /// @param id The abi encoded hash of the pool key struct for the pool that was modified
  /// @param sender The address that modified the pool
  /// @param tickLower The lower tick of the position
  /// @param tickUpper The upper tick of the position
  /// @param liquidityDelta The amount of liquidity that was added or removed
  /// @param salt The value used to create a unique liquidity position
  event ModifyLiquidity(
    bytes32 indexed id,
    address indexed sender,
    int24 tickLower,
    int24 tickUpper,
    int256 liquidityDelta,
    bytes32 salt
  );

  /// @notice Emitted for swaps between currency0 and currency1
  /// @param id The abi encoded hash of the pool key struct for the pool that was modified
  /// @param sender The address that initiated the swap call, and that received the callback
  /// @param amount0 The delta of the currency0 balance of the pool
  /// @param amount1 The delta of the currency1 balance of the pool
  /// @param sqrtPriceX96 The sqrt(price) of the pool after the swap, as a Q64.96
  /// @param liquidity The liquidity of the pool after the swap
  /// @param tick The log base 1.0001 of the price of the pool after the swap
  /// @param fee The fee collected upon every swap in the pool (including protocol fee and LP fee), denominated in hundredths of a bip
  /// @param protocolFee Single direction protocol fee from the swap, also denominated in hundredths of a bip
  event Swap(
    bytes32 indexed id,
    address indexed sender,
    int128 amount0,
    int128 amount1,
    uint160 sqrtPriceX96,
    uint128 liquidity,
    int24 tick,
    uint24 fee,
    uint16 protocolFee
  );

  /// @notice Emitted when donate happen
  /// @param id The abi encoded hash of the pool key struct for the pool that was modified
  /// @param sender The address that modified the pool
  /// @param amount0 The delta of the currency0 balance of the pool
  /// @param amount1 The delta of the currency1 balance of the pool
  /// @param tick The donated tick
  event Donate(
    bytes32 indexed id, address indexed sender, uint256 amount0, uint256 amount1, int24 tick
  );

  /// @notice Get the current value in slot0 of the given pool
  function getSlot0(bytes32 id)
    external
    view
    returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee);

  /// @notice Get the current value of liquidity of the given pool
  function getLiquidity(bytes32 id) external view returns (uint128 liquidity);

  /// @notice Get the current value of liquidity for the specified pool and position
  function getLiquidity(bytes32 id, address owner, int24 tickLower, int24 tickUpper, bytes32 salt)
    external
    view
    returns (uint128 liquidity);

  /// @notice Get the tick info about a specific tick in the pool
  function getPoolTickInfo(bytes32 id, int24 tick) external view returns (Tick.Info memory tickInfo);

  /// @notice Get the tick bitmap info about a specific range (a word range) in the pool
  function getPoolBitmapInfo(bytes32 id, int16 word) external view returns (uint256 tickBitmap);

  /// @notice Get the fee growth global for the given pool
  function getFeeGrowthGlobals(bytes32 id)
    external
    view
    returns (uint256 feeGrowthGlobal0x128, uint256 feeGrowthGlobal1x128);

  /// @notice Initialize the state for a given pool ID
  function initialize(PoolKey memory key, uint160 sqrtPriceX96) external returns (int24 tick);

  /// @notice Modify the position for the given pool
  /// @return delta The total balance delta of the caller of modifyLiquidity.
  /// @return feeDelta The balance delta of the fees generated in the liquidity range.
  function modifyLiquidity(
    PoolKey memory key,
    ModifyLiquidityParams memory params,
    bytes calldata hookData
  ) external returns (BalanceDelta delta, BalanceDelta feeDelta);

  /// @notice Swap against the given pool
  /// @param key The pool to swap in
  /// @param params The parameters for swapping
  /// @param hookData Any data to pass to the callback
  /// @return delta The balance delta of the address swapping
  /// @dev Swapping on low liquidity pools may cause unexpected swap amounts when liquidity available is less than amountSpecified.
  /// Additionally note that if interacting with hooks that have the BEFORE_SWAP_RETURNS_DELTA_FLAG or AFTER_SWAP_RETURNS_DELTA_FLAG
  /// the hook may alter the swap input/output. Integrators should perform checks on the returned swapDelta.
  function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData)
    external
    returns (BalanceDelta delta);
}
