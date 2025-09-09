// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PermitHelper} from 'ks-common-sc/src/libraries/token/PermitHelper.sol';

import {IERC721} from 'openzeppelin-contracts/contracts/interfaces/IERC721.sol';

/**
 * @notice Params structure for ERC721 token
 * @param token The address of the ERC721 token
 * @param tokenId The ID of the ERC721 token
 * @param permitData The permit data for the ERC721 token
 */
struct ERC721Params {
  address token;
  uint256 tokenId;
  bytes permitData;
}

using ERC721ParamsLibrary for ERC721Params global;

/// @notice Contains functions for processing ERC721 data
library ERC721ParamsLibrary {
  using PermitHelper for address;

  function collect(ERC721Params calldata self, address executor) internal {
    self.token.erc721Permit(self.tokenId, self.permitData);
    IERC721(self.token).safeTransferFrom(msg.sender, executor, self.tokenId);
  }
}
