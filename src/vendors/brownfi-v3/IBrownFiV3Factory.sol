// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBrownFiV3Factory {
  function pairConfig() external view returns (address);
  function feeTo() external view returns (address);
  function minPriceAge() external view returns (uint256);
  function priceOf(address token, uint256 priceAge) external view returns (uint256);
  function getAmmPrice(address pair) external view returns (uint256);

  function getSwapPrices(
    address pair,
    uint256 reserve0,
    uint256 reserve1,
    uint8 token0Decimals,
    uint8 token1Decimals,
    uint256 amount0Out,
    uint256 amount1Out
  )
    external
    view
    returns (
      uint256 sPrice0,
      uint256 sPrice1,
      uint256 pythPrice0,
      uint256 pythPrice1,
      uint256 ammPrice,
      uint256 adjPrice
    );
}
