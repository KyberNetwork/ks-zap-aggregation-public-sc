// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV3Pool {
  event Swap(
    address indexed sender,
    address indexed recipient,
    int256 amount0,
    int256 amount1,
    uint160 sqrtPriceX96,
    uint128 liquidity,
    int24 tick
  );

  function swap(
    address recipient,
    bool zeroForOne,
    int256 amountSpecified,
    uint160 sqrtPriceLimitX96,
    bytes calldata data
  ) external returns (int256 amount0, int256 amount1);

  function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;

  /// @dev Return types changed slightly so that our Uniswapv3ZapHelper contract is compatible with Univ3 forks
  /// with customized fee protocol. i.e PancakeV3 protocol.
  /// Rationale: Since we do not need the returned value `feeProtocol`, we make it uint256 so that it does not
  /// revert when decoding returned data.
  function slot0()
    external
    view
    returns (
      uint160 sqrtPriceX96,
      int24 tick,
      uint16 observationIndex,
      uint16 observationCardinality,
      uint16 observationCardinalityNext,
      uint256 feeProtocol, // uint8 from univ3 original
      bool unlocked
    );

  function liquidity() external view returns (uint128 liquidity);

  function tickSpacing() external view returns (int24);

  function tickBitmap(int16) external view returns (uint256);

  function ticks(int24 tick)
    external
    view
    returns (
      uint128 liquidityGross,
      int128 liquidityNet,
      uint256 feeGrowthOutside0X128,
      uint256 feeGrowthOutside1X128,
      int56 tickCumulativeOutside,
      uint160 secondsPerLiquidityOutsideX128,
      uint32 secondsOutside,
      bool initialized
    );

  function token0() external view returns (address);

  function token1() external view returns (address);

  function fee() external view returns (uint24);

  function positions(bytes32) external view returns (uint128, uint256, uint256, uint128, uint128);

  function feeGrowthGlobal0X128() external view returns (uint256);

  function feeGrowthGlobal1X128() external view returns (uint256);
}
