// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV2Pair {
  event Swap(
    address indexed sender,
    uint256 amount0In,
    uint256 amount1In,
    uint256 amount0Out,
    uint256 amount1Out,
    address indexed to
  );

  function factory() external view returns (address);
  function kLast() external view returns (uint256);

  function totalSupply() external view returns (uint256);
  function token0() external view returns (address);
  function token1() external view returns (address);
  function getReserves()
    external
    view
    returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
  function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
  function mint(address to) external returns (uint256 liquidity);
  function burn(address to) external returns (uint256 amount0, uint256 amount1);
}
