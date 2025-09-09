// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Params} from './ERC20Params.sol';
import {ERC721Params} from './ERC721Params.sol';
import {ValidateParams} from './ValidateParams.sol';

/**
 * @notice Params structure for zap action
 * @param erc20s The array of ERC20 params
 * @param erc721s The array of ERC721 params
 * @param permit2Data The permit2 data
 * @param validateParams The array of validate params
 * @param executor The address of the executor
 * @param executorData The data for the executor
 * @param deadline The deadline for the zap action
 * @param clientData The client data
 */
struct ZapParams {
  ERC20Params[] erc20s;
  ERC721Params[] erc721s;
  bytes permit2Data;
  ValidateParams[] validateParams;
  address executor;
  bytes executorData;
  uint256 deadline;
  bytes clientData;
}
