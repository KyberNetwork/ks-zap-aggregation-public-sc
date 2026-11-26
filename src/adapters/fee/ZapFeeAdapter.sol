// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IZapFeeAdapter} from '../../interfaces/adapters/fee/IZapFeeAdapter.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

/**
 * @title ZapFeeAdapter
 * @notice Transfers fees out of the balances of the account that delegatecalls it
 */
contract ZapFeeAdapter is IZapFeeAdapter {
  using TokenHelper for address;

  /// @dev Denominator of the fee rates
  uint256 internal constant FEE_DENOMINATOR = 1_000_000;

  /// @dev Bit that marks a solver fee value as a flat amount
  uint256 internal constant FLAT_FEE_FLAG = 1 << 255;

  /**
   * @inheritdoc IAHV2Callee
   * @dev `ownerData` is `abi.encode(TokenFeeCaps[])`. `solverData` is either empty, in which case
   * no fee is taken, or `abi.encode(uint256[][] fees)`, where `fees[i][j]` is the fee of `caps[j]`
   * of the token entry `i`. A fee with bit 255 set is a flat amount held in the other bits;
   * otherwise it is a rate out of 1,000,000.
   * @return The amounts transferred, as `abi.encode(uint256[][])` with one amount per cap of each
   * token entry
   */
  function execute(bytes calldata ownerData, bytes calldata solverData)
    external
    payable
    returns (bytes memory)
  {
    TokenFeeCaps[] memory entries = abi.decode(ownerData, (TokenFeeCaps[]));
    uint256[][] memory amounts = new uint256[][](entries.length);

    if (solverData.length == 0) {
      for (uint256 i = 0; i < entries.length; i++) {
        amounts[i] = new uint256[](entries[i].caps.length);
      }
      return abi.encode(amounts);
    }

    uint256[][] memory fees = abi.decode(solverData, (uint256[][]));
    require(fees.length == entries.length, MismatchedArrayLengths());

    for (uint256 i = 0; i < entries.length; i++) {
      amounts[i] = _takeFees(entries[i], fees[i]);
    }

    return abi.encode(amounts);
  }

  /// @dev Transfers the fees of a token entry and returns the amounts transferred, one per cap
  function _takeFees(TokenFeeCaps memory entry, uint256[] memory fees)
    internal
    returns (uint256[] memory amounts)
  {
    require(fees.length == entry.caps.length, MismatchedArrayLengths());

    address token = entry.token;
    // Every fee of an entry is computed from the balance of its token before the first transfer
    uint256 base = token.selfBalance();
    amounts = new uint256[](fees.length);

    for (uint256 j = 0; j < fees.length; j++) {
      address recipient = entry.caps[j].recipient;
      uint256 maxAmount = base * entry.caps[j].maxFeeRate / FEE_DENOMINATOR;

      // With FLAT_FEE_FLAG set, the fee is the flat amount held in the remaining bits.
      // Otherwise the fee is a rate out of FEE_DENOMINATOR.
      uint256 fee = fees[j];
      uint256 amount =
        fee & FLAT_FEE_FLAG != 0 ? fee & ~FLAT_FEE_FLAG : base * fee / FEE_DENOMINATOR;
      require(amount <= maxAmount, FeeExceedsCap(token, recipient, amount, maxAmount));

      if (amount != 0) {
        token.safeTransfer(recipient, amount);
        emit TakeFee(token, recipient, base, amount);
      }
      amounts[j] = amount;
    }
  }
}
