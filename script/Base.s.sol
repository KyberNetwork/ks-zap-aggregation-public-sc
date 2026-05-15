// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'ks-common-sc/script/Base.s.sol';

contract BaseZapAggScript is BaseScript {
  //some role executor not have yet, so we define here
  bytes32 public constant SIGNER_ROLE = keccak256('SIGNER_ROLE');
  bytes32 public constant GUARDIAN_ROLE = keccak256('GUARDIAN_ROLE');
  bytes32 public constant RESCUER_ROLE = keccak256('RESCUER_ROLE');

  mapping(uint256 => address) adminOf;
  mapping(uint256 => address[]) calldataSignersOf;
  mapping(uint256 => address[]) guardiansOf;
  mapping(uint256 => address[]) rescuersOf;
  mapping(uint256 => address) permit2Of;

  function _loadConfigs(string[] memory _chainIds) internal override {
    for (uint256 i = 0; i < _chainIds.length; i++) {
      uint256 chainId = vm.parseUint(_chainIds[i]);
      adminOf[chainId] = _readAddressByChainId('admin', chainId);
      calldataSignersOf[chainId] = _readAddressArrayByChainId('calldata-signers', chainId);
      guardiansOf[chainId] = _readAddressArrayByChainId('guardians', chainId);
      rescuersOf[chainId] = _readAddressArrayByChainId('rescuers', chainId);
      permit2Of[chainId] = _readAddressByChainId('permit2', chainId);
    }
  }
}
