// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISolidlyV2Pair} from '../solidly-v2/ISolidlyV2Pair.sol';

interface IShadowLegacyPair is ISolidlyV2Pair {
  function kLast() external view returns (uint256);
  function feeRecipient() external view returns (address);
  function feeSplit() external view returns (uint256);
  function metadata()
    external
    view
    returns (
      uint256 decimals0,
      uint256 decimals1,
      uint256 reserve0,
      uint256 reserve1,
      bool stable,
      address token0,
      address token1
    );
}
