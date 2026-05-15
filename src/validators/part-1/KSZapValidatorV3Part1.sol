// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {KSZapValidatorV3Base} from '../KSZapValidatorV3Base.sol';

import {ERC20sZapValidator} from './ERC20sZapValidator.sol';
import {ERC721sZapValidator} from './ERC721sZapValidator.sol';
import {LeverageFluidZapValidator} from './LeverageFluidZapValidator.sol';
import {LeverageGenericZapValidator} from './LeverageGenericZapValidator.sol';
import {PancakeInfinityZapValidator} from './PancakeInfinityZapValidator.sol';
import {UniswapV3ForkZapValidator} from './UniswapV3ForkZapValidator.sol';
import {UniswapV4ZapValidator} from './UniswapV4ZapValidator.sol';

import {ZapActions} from '../../libraries/ZapActions.sol';

contract KSZapValidatorV3Part1 is
  KSZapValidatorV3Base,
  UniswapV3ForkZapValidator,
  ERC20sZapValidator,
  UniswapV4ZapValidator,
  PancakeInfinityZapValidator,
  LeverageGenericZapValidator,
  ERC721sZapValidator,
  LeverageFluidZapValidator
{
  function getBeforeExecutionHandler(bytes32 zapAction)
    internal
    pure
    override
    returns (function(bytes calldata) internal returns (bytes memory))
  {
    if (zapAction == ZapActions.ZapInUniswapV3Fork) {
      return _beforeExecutionUniswapV3Fork;
    } else if (zapAction == ZapActions.RemoveUniswapV3Fork) {
      return _beforeExecutionUniswapV3Fork;
    } else if (zapAction == ZapActions.ZapInERC20s) {
      return _beforeExecutionZapInERC20s;
    } else if (zapAction == ZapActions.ZapInUniswapV4) {
      return _beforeExecutionUniswapV4;
    } else if (zapAction == ZapActions.RemoveUniswapV4) {
      return _beforeExecutionUniswapV4;
    } else if (zapAction == ZapActions.ZapInPancakeInfinity) {
      return _beforeExecutionPancakeInfinity;
    } else if (zapAction == ZapActions.RemovePancakeInfinity) {
      return _beforeExecutionPancakeInfinity;
    } else if (zapAction == ZapActions.ZapLeverageGeneric) {
      return _beforeExecutionZapLeverageGeneric;
    } else if (zapAction == ZapActions.ZapLeverageFluid) {
      return _beforeExecutionZapLeverageFluid;
    } else if (zapAction == ZapActions.ZapERC721s) {
      return _beforeExecutionDummy;
    } else {
      revert InvalidZapAction(zapAction);
    }
  }

  function getAfterExecutionHandler(bytes32 zapAction)
    internal
    pure
    override
    returns (function(bytes calldata, bytes calldata, bytes calldata) internal)
  {
    if (zapAction == ZapActions.ZapInUniswapV3Fork) {
      return _afterExecutionZapInUniswapV3Fork;
    } else if (zapAction == ZapActions.RemoveUniswapV3Fork) {
      return _afterExecutionRemoveUniswapV3Fork;
    } else if (zapAction == ZapActions.ZapInERC20s) {
      return _afterExecutionZapInERC20s;
    } else if (zapAction == ZapActions.ZapInUniswapV4) {
      return _afterExecutionZapInUniswapV4;
    } else if (zapAction == ZapActions.RemoveUniswapV4) {
      return _afterExecutionRemoveUniswapV4;
    } else if (zapAction == ZapActions.ZapInPancakeInfinity) {
      return _afterExecutionZapInPancakeInfinity;
    } else if (zapAction == ZapActions.RemovePancakeInfinity) {
      return _afterExecutionRemovePancakeInfinity;
    } else if (zapAction == ZapActions.ZapLeverageGeneric) {
      return _afterExecutionZapLeverageGeneric;
    } else if (zapAction == ZapActions.ZapERC721s) {
      return _afterExecutionZapERC721s;
    } else if (zapAction == ZapActions.ZapLeverageFluid) {
      return _afterExecutionZapLeverageFluid;
    } else {
      revert InvalidZapAction(zapAction);
    }
  }
}
