// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
  IZapAddLiquidityPreviewHelper
} from '../interfaces/settlers/IZapAddLiquidityPreviewHelper.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

/// @title AddLiquidityPreviewHelperCaller
/// @notice Queries a helper for the liquidity and the token amounts of an addition of liquidity
abstract contract AddLiquidityPreviewHelperCaller {
  /// @dev Calls `previewAddLiquidity` of the helper and returns its ABI-encoded result. Reverts with
  /// `AddressEmptyCode` when the helper has no code and with the revert data of the helper when the
  /// preview reverts.
  function _previewAddLiquidity(
    address helper,
    bytes memory fixedParams,
    bytes memory variableParams
  ) internal view returns (bytes memory result) {
    bytes memory data = abi.encodeCall(
      IZapAddLiquidityPreviewHelper.previewAddLiquidity, (fixedParams, variableParams)
    );

    return abi.decode(Address.functionStaticCall(helper, data), (bytes));
  }
}
