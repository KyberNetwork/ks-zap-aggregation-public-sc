// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
    uint256 expectedPositionInfo;
    uint256 minLiquidity;
    address recipient;
  }

  struct RemovePancakeInfinityAfterExecutionInput {
    uint256 liquidityRemoved;
    address recipient;
  }
}
