// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICurveTricrypto {
  function token() external view returns (address);

  function remove_liquidity(uint256 burn_amount, uint256[3] calldata min_amounts) external;

  function add_liquidity(uint256[3] calldata amounts, uint256 min_mint_amount)
    external
    returns (uint256);
}
