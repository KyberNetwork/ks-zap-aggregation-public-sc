// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'src/KSZapRouterV3.sol';
import 'script/Base.s.sol';

contract DeployKSZapRouterV3Script is BaseZapAggScript {
  string salt = '260206';

  /**
   * @dev Deploys KSZapRouterV3 contract to specified chains
   *
   * Usage:
   * # Deploy to multiple chains using chain ids or aliases
   * forge script DeployKSZapRouterV3Script \
   *   --sig "run(string[])" \
   *   "[1,137,8453]" \
   *   --broadcast
   */
  function run(string[] memory chainIds) public multiChain(chainIds) {
    if (bytes(salt).length == 0) {
      revert('salt is required');
    }
    string memory contractSalt = string.concat('KSZapRouterV3_', salt);

    bytes memory creationCode = abi.encodePacked(
      vm.getCode('KSZapRouterV3'),
      abi.encode(
        adminOf[vm.getChainId()],
        guardiansOf[vm.getChainId()],
        rescuersOf[vm.getChainId()],
        calldataSignersOf[vm.getChainId()]
      )
    );

    (address deployed,) = _create3Deploy(keccak256(bytes(contractSalt)), creationCode);
    if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
      _writeAddress('router', deployed);
    }
  }
}
