// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IKSZapRouterV3} from '../interfaces/IKSZapRouterV3.sol';

import {PermitHelper} from 'ks-common-sc/src/libraries/token/PermitHelper.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {IAllowanceTransfer} from 'ks-common-sc/src/interfaces/IAllowanceTransfer.sol';

/**
 * @notice Params structure for ERC20 token
 * @param token The address of the ERC20 token
 * @param targets The addresses to transfer the ERC20 token to
 * @param amounts The amounts of the ERC20 token to transfer
 * @param permitData The permit data for the ERC20 token
 */
struct ERC20Params {
  address token;
  address[] targets;
  uint256[] amounts;
  bytes permitData;
}

using ERC20ParamsLibrary for ERC20Params global;

/// @notice Contains functions for processing ERC20 data
library ERC20ParamsLibrary {
  using TokenHelper for address;
  using PermitHelper for address;

  /// @notice Collects the ERC20 token from the sender to the executor
  function collect(ERC20Params calldata self, IAllowanceTransfer permit2) internal {
    if (self.permitData.length == 0) {
      IAllowanceTransfer.AllowanceTransferDetails[] memory details =
        new IAllowanceTransfer.AllowanceTransferDetails[](self.targets.length);

      for (uint256 i = 0; i < self.targets.length; i++) {
        details[i] = IAllowanceTransfer.AllowanceTransferDetails({
          from: msg.sender, to: self.targets[i], amount: uint160(self.amounts[i]), token: self.token
        });
      }

      permit2.transferFrom(details);
    } else {
      if (self.token.isNative()) {
        for (uint256 i = 0; i < self.targets.length; i++) {
          self.targets[i].safeTransferNative(self.amounts[i]);
        }
      } else {
        self.token.callERC20Permit(msg.sender, self.permitData);

        for (uint256 i = 0; i < self.targets.length; i++) {
          self.token.safeTransferFrom(msg.sender, self.targets[i], self.amounts[i]);
        }
      }
    }
  }
}
