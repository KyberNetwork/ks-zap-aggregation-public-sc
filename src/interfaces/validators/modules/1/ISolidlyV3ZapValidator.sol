// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISolidlyV3ZapValidator {
  error ZapInSolidlyV3InvalidTickRange();
  error ZapInSolidlyV3InsufficientLiquidity();
  error RemoveSolidlyV3InvalidLiquidity();

  struct SolidlyV3BeforeExecutionInput {
    address pool;
    bytes32 positionKey;
  }

  struct ZapInSolidlyV3AfterExecutionInput {
    uint256 minLiquidity;
  }
}
