// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {ZapSolidlyV2Settler} from '../solidly-v2/ZapSolidlyV2Settler.sol';

import {IShadowLegacyPair} from '../../vendors/shadow-legacy/IShadowLegacyPair.sol';

import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

/// @title ZapShadowLegacySettler
/// @notice Adds liquidity to a Shadow Legacy pair with the token balances this contract holds, when
/// KSZapRouterV3 delegatecalls it in an owner call of an allowance hub fulfillment
/// @dev The total supply of a mint includes the liquidity that the pair mints to its fee recipient
/// at the start of `mint`.
contract ZapShadowLegacySettler is ZapSolidlyV2Settler {
  using Math for uint256;

  constructor(address _WETH) ZapSolidlyV2Settler(_WETH) {}

  /// @dev Returns the total supply of the pair plus the liquidity that `_mintFee` of the pair mints
  /// to its fee recipient: `feeSplit / 10_000` of the growth of sqrt(k) for a volatile pair, and of
  /// the growth of the fourth root of k for a stable pair
  function _actualTotalSupply(address pool, uint256 reserve0, uint256 reserve1)
    internal
    view
    override
    returns (uint256 totalSupply)
  {
    IShadowLegacyPair pair = IShadowLegacyPair(pool);
    totalSupply = pair.totalSupply();

    uint256 kLast = pair.kLast();
    if (kLast == 0 || pair.feeRecipient() == address(0)) {
      return totalSupply;
    }

    uint256 feeSplit = pair.feeSplit();
    (uint256 decimals0, uint256 decimals1,,, bool stable,,) = pair.metadata();

    if (stable) {
      uint256 k = _stableK(reserve0 * 1e18 / decimals0, reserve1 * 1e18 / decimals1);
      if (k > kLast) {
        uint256 fourthRoot = kLast.sqrt().mulDiv(1e36, k.sqrt()).sqrt();
        uint256 numerator = feeSplit * (1e18 - fourthRoot) * 1e18;
        uint256 denominator = 10_000 * 1e18 - feeSplit * (1e18 - fourthRoot);
        totalSupply += totalSupply * numerator / denominator / 1e18;
      }
    } else {
      uint256 rootK = (reserve0 * reserve1).sqrt();
      uint256 rootKLast = kLast.sqrt();
      if (rootK > rootKLast) {
        uint256 dueToProtocol = (rootK - rootKLast) * feeSplit / 10_000;
        totalSupply += totalSupply * dueToProtocol / (rootK - dueToProtocol);
      }
    }
  }

  /// @dev Returns x^3 * y + y^3 * x of the reserves normalised to 18 decimals, as `_k` of a stable
  /// pair computes it
  function _stableK(uint256 x, uint256 y) internal pure returns (uint256) {
    return (x * y / 1e18) * (x * x / 1e18 + y * y / 1e18) / 1e18;
  }
}
