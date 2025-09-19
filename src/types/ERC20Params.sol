// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapRouterV3} from '../interfaces/IKSZapRouterV3.sol';

import {PermitHelper} from 'ks-common-sc/src/libraries/token/PermitHelper.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/**
 * @notice Params structure for ERC20 token
 * @param token The address of the ERC20 token
 * @param amount The amount of the ERC20 token
 * @param permitData The permit data for the ERC20 token
 */
struct ERC20Params {
  address token;
  uint256 amount;
  bytes permitData;
}

using ERC20ParamsLibrary for ERC20Params global;

/// @notice Contains functions for processing ERC20 data
library ERC20ParamsLibrary {
  using TokenHelper for address;
  using PermitHelper for address;

  function collect(ERC20Params calldata self, address executor) internal returns (bool usePermit2) {
    if (self.token.isNative()) {
      require(msg.value >= self.amount, IKSZapRouterV3.NotEnoughMsgValue());
    }
    if (self.token.erc20Permit(msg.sender, self.permitData) || self.permitData.length == 0) {
      self.token.safeTransferFrom(msg.sender, executor, self.amount);
    } else {
      return true;
    }
  }
}
