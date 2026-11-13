// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

interface IArrakisV2Router {
  struct AddLiquidityData {
    uint256 amount0Max;
    uint256 amount1Max;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 amountSharesMin;
    address vault;
    address receiver;
    address gauge;
  }

  struct RemoveLiquidityData {
    uint256 burnAmount;
    uint256 amount0Min;
    uint256 amount1Min;
    address vault;
    address payable receiver;
    address gauge;
    bool receiveETH;
  }

  function addLiquidity(AddLiquidityData memory params)
    external
    payable
    returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);

  function removeLiquidity(RemoveLiquidityData memory params)
    external
    returns (uint256 amount0, uint256 amount1);
}
