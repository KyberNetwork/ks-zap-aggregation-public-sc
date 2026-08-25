// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWETH} from 'ks-common-sc/src/interfaces/IWETH.sol';

import {
  IERC20Metadata
} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol';

contract ImmutableState {
  address internal immutable original;

  IWETH internal immutable WETH;

  bool internal immutable IS_ARC_CHAIN_LIKE;

  constructor(address _WETH) {
    original = address(this);
    WETH = IWETH(_WETH);

    IS_ARC_CHAIN_LIKE = IERC20Metadata(_WETH).decimals() == 6;
  }
}
