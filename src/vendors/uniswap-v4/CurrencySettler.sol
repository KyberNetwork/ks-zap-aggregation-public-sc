// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPoolManager} from './IPoolManager.sol';

import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/// @notice Library used to interact with PoolManager.sol to settle any open deltas.
/// To settle a positive delta (a credit to the user), a user may take or mint.
/// To settle a negative delta (a debt on the user), a user make transfer or burn to pay off a debt.
/// @dev Note that sync() is called before any erc-20 transfer in `settle`.
library CurrencySettler {
  using TokenHelper for address;

  /// @notice Settle (pay) a currency to the PoolManager
  /// @param currency Currency to settle
  /// @param manager IPoolManager to settle to
  /// @param payer Address of the payer, the token sender
  /// @param amount Amount to send
  /// @param burn If true, burn the ERC-6909 token, otherwise ERC20-transfer to the PoolManager
  function settle(address currency, IPoolManager manager, address payer, uint256 amount, bool burn)
    internal
  {
    // for native currencies or burns, calling sync is not required
    // short circuit for ERC-6909 burns to support ERC-6909-wrapped native tokens
    if (burn) {
      manager.burn(payer, uint160(currency), amount);
    } else if (currency.isNative()) {
      manager.settle{value: amount}();
    } else {
      manager.sync(currency);
      if (payer != address(this)) {
        currency.safeTransferFrom(payer, address(manager), amount);
      } else {
        currency.safeTransfer(address(manager), amount);
      }
      manager.settle();
    }
  }

  /// @notice Take (receive) a currency from the PoolManager
  /// @param currency Currency to take
  /// @param manager IPoolManager to take from
  /// @param recipient Address of the recipient, the token receiver
  /// @param amount Amount to receive
  /// @param claims If true, mint the ERC-6909 token, otherwise ERC20-transfer from the PoolManager to recipient
  function take(
    address currency,
    IPoolManager manager,
    address recipient,
    uint256 amount,
    bool claims
  ) internal {
    claims
      ? manager.mint(recipient, uint160(currency), amount)
      : manager.take(currency, recipient, amount);
  }
}
