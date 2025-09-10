// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {KSZapValidatorV3Base} from '../KSZapValidatorV3Base.sol';

import {ERC20sZapValidator} from './1/ERC20sZapValidator.sol';
import {UniswapV3ZapValidator} from './1/UniswapV3ZapValidator.sol';

import {ZapType} from '../../libraries/ZapType.sol';

contract KSZapValidatorV3_1 is KSZapValidatorV3Base, UniswapV3ZapValidator, ERC20sZapValidator {
  function get_beforeExecution_handler(bytes32 zapType)
    internal
    pure
    override
    returns (function(bytes calldata) internal view returns (bytes memory))
  {
    if (zapType == ZapType.ZapIn__UniswapV3Fork || zapType == ZapType.Remove__UniswapV3Fork) {
      return _beforeExecution_UniswapV3Fork;
    } else if (zapType == ZapType.ZapIn__ERC20s) {
      return _beforeExecution_ZapIn__ERC20s;
    } else {
      revert InvalidZapType(zapType);
    }
  }

  function get_afterExecution_handler(bytes32 zapType)
    internal
    pure
    override
    returns (function(bytes calldata, bytes calldata, bytes calldata) internal view)
  {
    if (zapType == ZapType.ZapIn__UniswapV3Fork) {
      return _afterExecution_ZapIn__UniswapV3Fork;
    } else if (zapType == ZapType.Remove__UniswapV3Fork) {
      return _afterExecution_Remove__UniswapV3Fork;
    } else if (zapType == ZapType.ZapIn__ERC20s) {
      return _afterExecution_ZapIn__ERC20s;
    } else {
      revert InvalidZapType(zapType);
    }
  }
}
