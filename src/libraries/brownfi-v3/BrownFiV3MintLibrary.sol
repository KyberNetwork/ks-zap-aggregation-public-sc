// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

/// @title BrownFiV3MintLibrary
/// @notice Computes the liquidity and the token amounts of a BrownFi V3 mint
library BrownFiV3MintLibrary {
  using Math for uint256;

  /// @dev Pair state and token amounts of a mint
  struct MintState {
    uint8 token0Decimals;
    uint8 token1Decimals;
    uint8 quoteTokenIndex;
    uint256 price0;
    uint256 price1;
    uint256 ammPrice;
    uint256 reserve0;
    uint256 reserve1;
    uint256 totalSupply;
    uint256 amount0;
    uint256 amount1;
  }

  uint256 internal constant Q64 = 1 << 64;
  uint256 internal constant MINIMUM_LIQUIDITY = 1000;

  /**
   * @dev Computes the liquidity minted by the amounts in `state` and the amounts of each token it
   * consumes.
   * @param state The pair state and the token amounts
   * @return liquidity The liquidity minted
   * @return addedAmount0 The amount of token0 consumed
   * @return addedAmount1 The amount of token1 consumed
   */
  function previewMint(MintState memory state)
    internal
    pure
    returns (uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    uint256 amount0 = to18(state.token0Decimals, state.amount0);
    uint256 amount1 = to18(state.token1Decimals, state.amount1);

    if (state.totalSupply == 0) {
      uint256 value0 = state.price0 * amount0 + state.price1 * amount1;
      if (value0 / Q64 <= MINIMUM_LIQUIDITY) {
        return (0, 0, 0);
      }
      return (value0 / Q64 - MINIMUM_LIQUIDITY, state.amount0, state.amount1);
    }

    bool baseIsToken0 = token0IsBase(state);
    uint256 baseIn = baseIsToken0 ? amount0 : amount1;
    uint256 quoteIn = baseIsToken0 ? amount1 : amount0;
    uint256 baseReserve = to18(
      baseIsToken0 ? state.token0Decimals : state.token1Decimals,
      baseIsToken0 ? state.reserve0 : state.reserve1
    );
    uint256 quoteReserve = to18(
      baseIsToken0 ? state.token1Decimals : state.token0Decimals,
      baseIsToken0 ? state.reserve1 : state.reserve0
    );

    uint256 pythBase = baseIsToken0 ? state.price0 : state.price1;
    uint256 pythQuote = baseIsToken0 ? state.price1 : state.price0;
    if (pythBase == 0 || pythQuote == 0 || baseReserve == 0 || quoteReserve == 0) {
      return (0, 0, 0);
    }

    uint256 n1 = Math.min(baseIn * pythBase, quoteIn * pythQuote) * 2;
    uint256 v1 = baseReserve * pythBase + quoteReserve * pythQuote;
    uint256 lp1 = Math.mulDiv(state.totalSupply, n1, v1);

    uint256 ammPrice = state.ammPrice;
    liquidity = lp1;
    if (ammPrice > 0) {
      uint256 n2 = Math.min(baseIn * ammPrice, quoteIn * Q64) * 2;
      uint256 v2 = baseReserve * ammPrice + quoteReserve * Q64;
      liquidity = Math.min(lp1, Math.mulDiv(state.totalSupply, n2, v2));
    }

    if (liquidity == 0) {
      return (0, 0, 0);
    }

    (uint256 addedBase, uint256 addedQuote) = _amountsForLiquidity(
      state.totalSupply, liquidity, baseReserve, quoteReserve, pythBase, pythQuote, ammPrice
    );

    if (baseIsToken0) {
      addedAmount0 = from18RoundUp(state.token0Decimals, addedBase);
      addedAmount1 = from18RoundUp(state.token1Decimals, addedQuote);
    } else {
      addedAmount0 = from18RoundUp(state.token0Decimals, addedQuote);
      addedAmount1 = from18RoundUp(state.token1Decimals, addedBase);
    }
  }

  /// @dev Returns whether token0 is the base token
  function token0IsBase(MintState memory state) internal pure returns (bool) {
    return state.quoteTokenIndex == 1;
  }

  /// @dev Scales an amount of a token to 18 decimals
  function to18(uint8 tokenDecimals, uint256 amount) internal pure returns (uint256) {
    return amount * 10 ** uint256(18 - tokenDecimals);
  }

  /// @dev Scales an amount from 18 decimals to the decimals of a token, rounding up
  function from18RoundUp(uint8 tokenDecimals, uint256 amount) internal pure returns (uint256) {
    return amount.ceilDiv(10 ** uint256(18 - tokenDecimals));
  }

  /// @dev Computes the base and quote amounts that mint `liquidity`
  function _amountsForLiquidity(
    uint256 totalSupply,
    uint256 liquidity,
    uint256 baseReserve,
    uint256 quoteReserve,
    uint256 pythBase,
    uint256 pythQuote,
    uint256 ammPrice
  ) private pure returns (uint256 addedBase, uint256 addedQuote) {
    uint256 denominator = totalSupply * 2;
    uint256 value1 = Math.mulDiv(
      liquidity, baseReserve * pythBase + quoteReserve * pythQuote, denominator, Math.Rounding.Ceil
    );
    addedBase = value1.ceilDiv(pythBase);
    addedQuote = value1.ceilDiv(pythQuote);

    if (ammPrice > 0) {
      uint256 value2 = Math.mulDiv(
        liquidity, baseReserve * ammPrice + quoteReserve * Q64, denominator, Math.Rounding.Ceil
      );
      uint256 addedBase2 = value2.ceilDiv(ammPrice);
      uint256 addedQuote2 = value2.ceilDiv(Q64);
      addedBase = addedBase > addedBase2 ? addedBase : addedBase2;
      addedQuote = addedQuote > addedQuote2 ? addedQuote : addedQuote2;
    }
  }
}
