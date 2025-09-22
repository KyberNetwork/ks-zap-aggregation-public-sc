// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CLPositionInfo} from '../../../../vendors/pancake-infinity/Types.sol';

interface IPancakeInfinityZapValidator {
  error ZapInPancakeInfinityInsufficientLiquidity();
  error ZapInPancakeInfinityInvalidPositionInfo();
  error PancakeInfinityInvalidPositionOwner();
  error RemovePancakeInfinityInvalidLiquidity();

  struct PancakeInfinityBeforeExecutionInput {
    address posManager;
    uint256 tokenId;
  }

  struct ZapInPancakeInfinityAfterExecutionInput {
    CLPositionInfo expectedPositionInfo;
    uint256 minLiquidity;
    address recipient;
  }

  struct RemovePancakeInfinityAfterExecutionInput {
    uint256 liquidityRemoved;
    address recipient;
  }
}
