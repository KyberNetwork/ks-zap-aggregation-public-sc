// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {LibTransient} from 'solady/utils/LibTransient.sol';

/// @title ZapAgainRecord
/// @notice Stores in transient storage the parameters of the zap again that the solver passes to a
/// pool swap, for the adapter of the owner call that follows
/// @dev The record lives in the transient storage of the contract that runs the pool swap and the
/// adapter, the router. A pool swap stores the record and the adapter loads it. Empty parameters
/// mean no record.
library ZapAgainRecord {
  using LibTransient for LibTransient.TBytes;

  /// @dev Transient slot of the record
  bytes32 private constant SLOT = bytes32(erc7201('ks.zap.zap-again-record'));

  /**
   * @dev Stores the parameters, replacing the previous record
   * @param params The ABI-encoded parameters of the zap again, empty for no record
   */
  function store(bytes calldata params) internal {
    LibTransient.tBytes(SLOT).setCalldata(params);
  }

  /**
   * @dev Clears the record and returns its parameters
   * @return params The ABI-encoded parameters, empty when no record exists
   */
  function load() internal returns (bytes memory params) {
    LibTransient.TBytes storage record = LibTransient.tBytes(SLOT);
    params = record.get();
    record.clear();
  }
}
