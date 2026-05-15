// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'script/Base.s.sol';
import 'src/validators/part-1/KSZapValidatorV3Part1.sol';

contract DeployValidatorsScript is BaseZapAggScript {
  string salt = '260206';

  /**
   * @dev Deploys KSZapValidatorV3Part1 contract to specified chains
   *
   * Usage:
   * # Deploy to multiple chains using chain ids or aliases
   * forge script DeployValidatorsScript \
   *   --sig "run(string[],string[])" \
   *   "[1,137,8453]" \
   *   "[1]" \
   *   --broadcast
   */
  function run(string[] memory chainIds, string[] memory validatorIds) public multiChain(chainIds) {
    if (bytes(salt).length == 0) {
      revert('salt is required');
    }

    for (uint256 i = 0; i < validatorIds.length; i++) {
      string memory validatorId = validatorIds[i];

      string memory validatorSalt = string.concat('KSZapValidatorV3Part', validatorId, '_', salt);
      bytes memory creationCode = vm.getCode(string.concat('KSZapValidatorV3Part', validatorId));

      (address deployed,) = _create3Deploy(keccak256(bytes(validatorSalt)), creationCode);

      if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
        vm.writeJson(
          vm.toString(deployed),
          string.concat(path, 'validators', '.json'),
          string.concat(_dotChainId(), '.', 'KSZapValidatorV3Part', validatorId)
        );
      }
    }
  }
}
