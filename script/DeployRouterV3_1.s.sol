// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'script/Base.s.sol';
import 'src/KSZapRouterV3_1.sol';

contract DeployKSZapRouterV3_1Script is BaseZapAggScript {
  string salt = '260717';

  /**
   * @dev Deploys KSZapRouterV3_1 contract to specified chains
   *
   * Usage:
   * # Deploy to multiple chains using chain ids or aliases
   * forge script DeployKSZapRouterV3_1Script \
   *   --sig "run(string[])" \
   *   "[1,137,8453]" \
   *   --broadcast
   */
  function run(string[] memory chainIds) public multiChain(chainIds) {
    if (bytes(salt).length == 0) {
      revert('salt is required');
    }
    string memory contractSalt = string.concat('KSZapRouterV3_1_', salt);

    bytes memory creationCode = abi.encodePacked(
      vm.getCode('KSZapRouterV3_1'),
      abi.encode(
        adminOf[vm.getChainId()],
        guardiansOf[vm.getChainId()],
        rescuersOf[vm.getChainId()],
        calldataSignersOf[vm.getChainId()]
      )
    );

    (address deployed,) = _create3Deploy(keccak256(bytes(contractSalt)), creationCode);
    if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
      _writeAddress('router-v3_1', deployed);
    }
  }
}
