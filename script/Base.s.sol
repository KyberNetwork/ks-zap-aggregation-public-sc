// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'ks-common-sc/script/Base.s.sol';

/// @title BaseZapAggScript
/// @notice Base of the deployment scripts, which loads the wrapped native token of each chain
contract BaseZapAggScript is BaseScript {
  mapping(uint256 => address) wethOf;

  /// @dev Loads the wrapped native token of each chain from `script/config/weth.json`
  function _loadConfigs(string[] memory _chainIds) internal override {
    for (uint256 i = 0; i < _chainIds.length; i++) {
      uint256 chainId = vm.parseUint(_chainIds[i]);
      wethOf[chainId] = _readAddressByChainId('weth', chainId);
    }
  }

  /// @dev Returns the hash of the current git commit
  function _getCurrentCommit() internal returns (string memory) {
    string[] memory cmd = new string[](3);
    cmd[0] = 'git';
    cmd[1] = 'rev-parse';
    cmd[2] = 'HEAD';
    bytes memory result = vm.ffi(cmd);
    string memory commitHash = vm.toString(result);
    // Remove "0x" prefix
    return vm.replace(commitHash, '0x', '');
  }
}
