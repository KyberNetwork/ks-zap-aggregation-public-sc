// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CustomRevert} from 'ks-common-sc/src/libraries/CustomRevert.sol';

/**
 * @notice Params structure for contract call
 * @param target The address of the target
 * @param data The data for the contract call
 * @param isDelegateCall Whether to delegate call the contract
 */
struct ContractCall {
  address target;
  bytes data;
  bool isDelegateCall;
}

using ContractCallLibrary for ContractCall global;

/// @notice Returns the return data of the last call
function lastCallReturnData() pure returns (bytes memory returnData) {
  assembly ('memory-safe') {
    returnData := mload(0x40)
    mstore(0x40, add(returnData, add(returndatasize(), 0x20)))
    mstore(returnData, returndatasize())
    returndatacopy(add(returnData, 0x20), 0, returndatasize())
  }
}

library ContractCallLibrary {
  /// @notice Thrown when a call fails
  error CallFailed();

  /// @notice Thrown when a delegate call fails
  error DelegateCallFailed();

  /// @notice Runs the call and reverts with its wrapped revert data when it fails
  function execute(ContractCall calldata self) internal {
    bool success;
    if (self.isDelegateCall) {
      /// The target is given in the signed call list.
      /// The delegatecall flag is set per call in the signed call list.
      // forge-lint: disable-next-line(controlled-delegatecall)
      (success,) = self.target.delegatecall(self.data);
    } else {
      (success,) = self.target.call(self.data);
    }

    if (!success) {
      CustomRevert.bubbleUpAndRevertWith(
        self.target,
        bytes4(self.data),
        self.isDelegateCall
          ? ContractCallLibrary.DelegateCallFailed.selector
          : ContractCallLibrary.CallFailed.selector
      );
    }
  }
}
