// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface ISolidlyV3Pool {
  /// @notice The first of the two tokens of the pool, sorted by address
  /// @return The token contract address
  function token0() external view returns (address);

  /// @notice The second of the two tokens of the pool, sorted by address
  /// @return The token contract address
  function token1() external view returns (address);

  /// @notice The pool tick spacing
  /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
  /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
  /// This value is an int24 to avoid casting even though it is always positive.
  /// @return The tick spacing
  function tickSpacing() external view returns (int24);

  /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
  /// when accessed externally.
  /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
  /// tick The current tick of the pool, i.e. according to the last tick transition that was run.
  /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
  /// boundary.
  /// fee The pool's current fee in hundredths of a bip, i.e. 1e-6
  /// unlocked Whether the pool is currently locked to reentrancy
  function slot0()
    external
    view
    returns (uint160 sqrtPriceX96, int24 tick, uint24 fee, bool unlocked);

  /// @notice The currently in range liquidity available to the pool
  /// @dev This value has no relationship to the total liquidity across all ticks
  function liquidity() external view returns (uint128);

  /// @notice Look up information about a specific tick in the pool
  /// @param tick The tick to look up
  /// @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
  /// tick upper,
  /// liquidityNet how much liquidity changes when the pool price crosses the tick,
  /// initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
  /// Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
  /// In addition, these values are only relative and must be used only in comparison to previous snapshots for
  /// a specific position.
  function ticks(int24 tick)
    external
    view
    returns (uint128 liquidityGross, int128 liquidityNet, bool initialized);

  /// @notice Returns 256 packed tick initialized boolean values. See TickBitmap for more information
  function tickBitmap(int16 wordPosition) external view returns (uint256);

  /// @notice Returns the information about a position by the position's key
  /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper
  /// @return _liquidity The amount of liquidity in the position,
  /// Returns tokensOwed0 the computed amount of token0 owed to the position as of the last mint/burn/poke,
  /// Returns tokensOwed1 the computed amount of token1 owed to the position as of the last mint/burn/poke
  function positions(bytes32 key)
    external
    view
    returns (uint128 _liquidity, uint128 tokensOwed0, uint128 tokensOwed1);

  /// @notice Adds liquidity for the given recipient/tickLower/tickUpper position
  /// Uses callback for payments and includes additional slippage/deadline protection
  /// @dev The caller of this method receives a callback in the form of ISolidlyV3MintCallback#solidlyV3MintCallback
  /// in which they must pay any token0 or token1 owed for the liquidity
  /// @param recipient The address for which the liquidity will be created
  /// @param tickLower The lower tick of the position in which to add liquidity
  /// @param tickUpper The upper tick of the position in which to add liquidity
  /// @param amount The amount of liquidity to mint
  /// @param amount0Min The minimum amount of token0 to spend, which serves as a slippage check
  /// @param amount1Min The minimum amount of token1 to spend, which serves as a slippage check
  /// @param deadline A constraint on the time by which the mint transaction must mined
  /// @param data Any data to be passed through to the callback
  /// @return amount0 The amount of token0 that was paid to mint the given amount of liquidity. Matches the value in the callback
  /// @return amount1 The amount of token1 that was paid to mint the given amount of liquidity. Matches the value in the callback
  function mint(
    address recipient,
    int24 tickLower,
    int24 tickUpper,
    uint128 amount,
    uint256 amount0Min,
    uint256 amount1Min,
    uint256 deadline,
    bytes calldata data
  ) external returns (uint256 amount0, uint256 amount1);

  /// @notice Convenience method to burn liquidity and then collect owed tokens in one go
  /// @param recipient The address which should receive the tokens collected
  /// @param tickLower The lower tick of the position for which to collect tokens
  /// @param tickUpper The upper tick of the position for which to collect tokens
  /// @param amountToBurn How much liquidity to burn
  /// @param amount0ToCollect How much token0 should be withdrawn from the tokens owed
  /// @param amount1ToCollect How much token1 should be withdrawn from the tokens owed
  /// @return amount0FromBurn The amount of token0 accrued to the position from the burn
  /// @return amount1FromBurn The amount of token1 accrued to the position from the burn
  /// @return amount0Collected The amount of token0 collected from the positions
  /// @return amount1Collected The amount of token1 collected from the positions
  function burnAndCollect(
    address recipient,
    int24 tickLower,
    int24 tickUpper,
    uint128 amountToBurn,
    uint128 amount0ToCollect,
    uint128 amount1ToCollect
  )
    external
    returns (
      uint256 amount0FromBurn,
      uint256 amount1FromBurn,
      uint128 amount0Collected,
      uint128 amount1Collected
    );

  /// @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
  /// @dev Tokens must be collected separately via a call to #collect
  /// @param tickLower The lower tick of the position for which to burn liquidity
  /// @param tickUpper The upper tick of the position for which to burn liquidity
  /// @param amount How much liquidity to burn
  /// @return amount0 The amount of token0 sent to the recipient
  /// @return amount1 The amount of token1 sent to the recipient
  function burn(int24 tickLower, int24 tickUpper, uint128 amount)
    external
    returns (uint256 amount0, uint256 amount1);

  /// @notice Swap token0 for token1, or token1 for token0
  /// Uses a callback for payments; no additional slippage/deadline protection or referrer tracking
  /// @dev The caller of this method receives a callback in the form of ISolidlyV3MintCallback#solidlyV3SwapCallback
  /// in which they must pay any token0 or token1 owed for the swap
  /// @param recipient The address to receive the output of the swap
  /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
  /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
  /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
  /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
  /// @param data Any data to be passed through to the callback
  /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
  /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
  function swap(
    address recipient,
    bool zeroForOne,
    int256 amountSpecified,
    uint160 sqrtPriceLimitX96,
    bytes calldata data
  ) external returns (int256 amount0, int256 amount1);
}
