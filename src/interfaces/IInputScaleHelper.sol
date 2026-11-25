// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IInputScaleHelper
/// @notice Interface of the helpers that scale the input amount of swap data
interface IInputScaleHelper {
  /**
   * @notice Rewrites the swap data for a new input amount
   * @param data The calldata of the swap
   * @param newAmount The input amount to scale the swap data to
   * @return success Whether the swap data was scaled
   * @return newData The scaled swap data
   */
  function getScaledInputData(bytes calldata data, uint256 newAmount)
    external
    view
    returns (bool success, bytes memory newData);
}
