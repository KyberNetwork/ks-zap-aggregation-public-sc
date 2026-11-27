// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'script/Base.s.sol';

/// @title DeployAdaptersScript
/// @notice Deploys the zap adapters to the given chains with CREATE3
contract DeployAdaptersScript is BaseZapAggScript {
  string salt = '261127';

  /**
   * @notice Deploys the named adapters to each of the chains
   * @dev Usage, with the adapter names being contract names under `src/adapters`:
   *
   * forge script script/DeployAdapters.s.sol:DeployAdaptersScript \
   *   --sig 'run(string[],string[])' \
   *   '[1,137,8453]' \
   *   '[ZapUniswapV3Adapter,ZapFeeAdapter]' \
   *   --sender <deployer> \
   *   --broadcast
   *
   * Without `--broadcast` the run is a dry run that writes no file.
   *
   * The leverage adapters refer to each other through their CREATE3 addresses, so KSSafeAccountHub,
   * ZapLeverageAdapter and FlashLoanAdapter are deployed in one run or with the same deployer and
   * salt. FlashLoanAdapter reads `proxy-callee`, and KSSafeAccountHub reads `allowance-hub-v2`,
   * `safe-proxy-factory` and `safe-singleton` from the config of the chain.
   * @param chainIds Chain ids to deploy to
   * @param adapterNames Contract names of the adapters to deploy
   */
  function run(string[] memory chainIds, string[] memory adapterNames) public multiChain(chainIds) {
    if (bytes(salt).length == 0) {
      revert('salt is required');
    }

    for (uint256 i = 0; i < adapterNames.length; i++) {
      string memory adapterName = adapterNames[i];
      string memory contractSalt = string.concat(adapterName, '_', salt);

      bytes memory creationCode =
        abi.encodePacked(vm.getCode(adapterName), _constructorArgs(adapterName));

      (address adapter,) = _create3Deploy(keccak256(bytes(contractSalt)), creationCode);

      if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
        vm.writeJson(
          vm.toString(adapter),
          string.concat(path, 'adapters', '.json'),
          string.concat(_dotChainId(), '.', adapterName)
        );
        // Write commit hash
        string memory commitHash = _getCurrentCommit();
        vm.writeJson(
          commitHash,
          string.concat(path, 'adapter-commits', '.json'),
          string.concat(_dotChainId(), '.', adapterName)
        );
      }
    }
  }

  /// @dev Returns the ABI-encoded constructor arguments of an adapter on the current chain. The
  /// addresses of the adapters that refer to each other are the CREATE3 addresses of the deployer.
  function _constructorArgs(string memory adapterName) internal returns (bytes memory) {
    bytes32 nameHash = keccak256(bytes(adapterName));
    if (
      nameHash == keccak256('ZapFeeAdapter') || nameHash == keccak256('ZapSwapAdapter')
        || nameHash == keccak256('ZapRefundAdapter')
    ) {
      return '';
    }

    address weth = wethOf[vm.getChainId()];

    if (nameHash == keccak256('FlashLoanAdapter')) {
      address proxyCallee = _readAddress('proxy-callee');
      return abi.encode(weth, proxyCallee);
    }

    if (nameHash == keccak256('KSSafeAccountHub')) {
      address allowanceHub = _readAddress('allowance-hub-v2');
      address flashLoanAdapter = _create3Address('FlashLoanAdapter');
      address safeProxyFactory = _readAddress('safe-proxy-factory');
      address safeSingleton = _readAddress('safe-singleton');
      string memory name = 'KSSafeAccountHub';
      string memory symbol = 'SAFEAUTH';
      return
        abi.encode(allowanceHub, flashLoanAdapter, safeProxyFactory, safeSingleton, name, symbol);
    }

    if (nameHash == keccak256('ZapLeverageAdapter')) {
      address safeAccountHub = _create3Address('KSSafeAccountHub');
      address flashLoanAdapter = _create3Address('FlashLoanAdapter');
      return abi.encode(weth, safeAccountHub, flashLoanAdapter);
    }

    return abi.encode(weth);
  }

  /// @dev Returns the address that the CREATE3 factory deploys the adapter to for the deployer
  function _create3Address(string memory adapterName) internal returns (address) {
    bytes32 contractSalt = keccak256(bytes(string.concat(adapterName, '_', salt)));
    (, address deployer,) = vm.readCallers();
    return ICREATE3Factory(_create3Deployer()).getDeployed(deployer, contractSalt);
  }
}
