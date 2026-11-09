// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICurveStableSwap {
  function coins(uint256 index) external view returns (address);

  function N_COINS() external view returns (uint256);

  function remove_liquidity(uint256 burn_amount, uint256[] calldata min_amounts) external;

  function add_liquidity(uint256[] calldata amounts, uint256 min_mint_amount)
    external
    returns (uint256);
}
