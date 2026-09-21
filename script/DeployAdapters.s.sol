// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'script/Base.s.sol';

contract DeployAdaptersScript is BaseZapAggScript {
  string salt = '260921';

  /**
   * @dev Deploys adapters (FlashLoanAdapter, *ActionAdapter) to specified chains
   *
   * Usage:
   * # Deploy to multiple chains using chain ids or aliases
   * forge script DeployAdaptersScript \
   *   --sig "run(string[],string[])" \
   *   "[1,137,8453]" \
   *   "[FlashLoanAdapter,AaveV3ActionAdapter,MorphoActionAdapter]" \
   *   --broadcast
   */
  function run(string[] memory chainIds, string[] memory adapterNames) public multiChain(chainIds) {
    if (bytes(salt).length == 0) {
      revert('salt is required');
    }

    for (uint256 i = 0; i < adapterNames.length; i++) {
      string memory adapterName = adapterNames[i];

      string memory adapterSalt = string.concat(adapterName, '_', salt);
      bytes memory creationCode =
        abi.encodePacked(vm.getCode(adapterName), _constructorArgs(adapterName));

      (address deployed,) = _create3Deploy(keccak256(bytes(adapterSalt)), creationCode);

      if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
        vm.writeJson(
          vm.toString(deployed),
          string.concat(path, 'adapters', '.json'),
          string.concat(_dotChainId(), '.', adapterName)
        );
      }
    }
  }

  function _constructorArgs(string memory adapterName) internal returns (bytes memory) {
    // FlashLoanAdapter inherits ImmutableState(WETH), lending action adapters take no args
    if (keccak256(bytes(adapterName)) == keccak256('FlashLoanAdapter')) {
      return abi.encode(_readAddress('weth'));
    }
    return '';
  }
}
