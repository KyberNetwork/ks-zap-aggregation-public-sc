// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {KSZapValidatorV3Base} from '../KSZapValidatorV3Base.sol';

import {ERC20sZapValidator} from './1/ERC20sZapValidator.sol';
import {PancakeInfinityZapValidator} from './1/PancakeInfinityZapValidator.sol';
import {SolidlyV3ZapValidator} from './1/SolidlyV3ZapValidator.sol';
import {UniswapV3ForkZapValidator} from './1/UniswapV3ForkZapValidator.sol';
import {UniswapV4ZapValidator} from './1/UniswapV4ZapValidator.sol';

import {ZapType} from '../../libraries/ZapType.sol';

contract KSZapValidatorV3_1 is
  KSZapValidatorV3Base,
  UniswapV3ForkZapValidator,
  ERC20sZapValidator,
  SolidlyV3ZapValidator,
  UniswapV4ZapValidator,
  PancakeInfinityZapValidator
{
  function getBeforeExecutionHandler(bytes32 zapType)
    internal
    pure
    override
    returns (function(bytes calldata) internal view returns (bytes memory))
  {
    if (zapType == ZapType.ZapInUniswapV3Fork) {
      return _beforeExecutionUniswapV3Fork;
    } else if (zapType == ZapType.RemoveUniswapV3Fork) {
      return _beforeExecutionUniswapV3Fork;
    } else if (zapType == ZapType.ZapInERC20s) {
      return _beforeExecutionZapInERC20s;
    } else if (zapType == ZapType.ZapInSolidlyV3) {
      return _beforeExecutionZapInSolidlyV3;
    } else if (zapType == ZapType.ZapInUniswapV4) {
      return _beforeExecutionUniswapV4;
    } else if (zapType == ZapType.RemoveUniswapV4) {
      return _beforeExecutionUniswapV4;
    } else if (zapType == ZapType.ZapInPancakeInfinity) {
      return _beforeExecutionPancakeInfinity;
    } else if (zapType == ZapType.RemovePancakeInfinity) {
      return _beforeExecutionPancakeInfinity;
    } else {
      revert InvalidZapType(zapType);
    }
  }

  function getAfterExecutionHandler(bytes32 zapType)
    internal
    pure
    override
    returns (function(bytes calldata, bytes calldata, bytes calldata) internal view)
  {
    if (zapType == ZapType.ZapInUniswapV3Fork) {
      return _afterExecutionZapInUniswapV3Fork;
    } else if (zapType == ZapType.RemoveUniswapV3Fork) {
      return _afterExecutionRemoveUniswapV3Fork;
    } else if (zapType == ZapType.ZapInERC20s) {
      return _afterExecutionZapInERC20s;
    } else if (zapType == ZapType.ZapInSolidlyV3) {
      return _afterExecutionZapInSolidlyV3;
    } else if (zapType == ZapType.ZapInUniswapV4) {
      return _afterExecutionZapInUniswapV4;
    } else if (zapType == ZapType.RemoveUniswapV4) {
      return _afterExecutionRemoveUniswapV4;
    } else if (zapType == ZapType.ZapInPancakeInfinity) {
      return _afterExecutionZapInPancakeInfinity;
    } else if (zapType == ZapType.RemovePancakeInfinity) {
      return _afterExecutionRemovePancakeInfinity;
    } else {
      revert InvalidZapType(zapType);
    }
  }
}
