// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IInputScaleHelper {
  function getScaledInputData(bytes calldata data, uint256 newAmount)
    external
    view
    returns (bool success, bytes memory newData);
}
