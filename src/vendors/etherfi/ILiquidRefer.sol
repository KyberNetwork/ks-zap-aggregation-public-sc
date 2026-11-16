// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice ether.fi's LiquidRefer deposit router, sitting in front of whitelisted Teller
/// contracts and attaching a referrer to each deposit.
/// See https://etherscan.io/address/0xc1210B06ba09964c4d25F0012cd5682D3Ff0A0CA#code
interface ILiquidRefer {
  function deposit(
    address teller,
    address depositAsset,
    uint256 depositAmount,
    uint256 minimumMint,
    address referrer
  ) external returns (uint256 shares);
}
