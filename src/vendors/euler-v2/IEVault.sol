// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {IERC4626} from 'openzeppelin-contracts/contracts/interfaces/IERC4626.sol';

// Full interface of EVault and all it's modules

/// @title IBorrowing
/// @notice Interface of the EVault's Borrowing module
interface IBorrowing {
  /// @notice Sum of all outstanding debts, in underlying units (increases as interest is accrued)
  /// @return The total borrows in asset units
  function totalBorrows() external view returns (uint256);

  /// @notice Sum of all outstanding debts, in underlying units scaled up by shifting
  /// INTERNAL_DEBT_PRECISION_SHIFT bits
  /// @return The total borrows in internal debt precision
  function totalBorrowsExact() external view returns (uint256);

  /// @notice Balance of vault assets as tracked by deposits/withdrawals and borrows/repays
  /// @return The amount of assets the vault tracks as current direct holdings
  function cash() external view returns (uint256);

  /// @notice Debt owed by a particular account, in underlying units
  /// @param account Address to query
  /// @return The debt of the account in asset units
  function debtOf(address account) external view returns (uint256);

  /// @notice Debt owed by a particular account, in underlying units scaled up by shifting
  /// INTERNAL_DEBT_PRECISION_SHIFT bits
  /// @param account Address to query
  /// @return The debt of the account in internal precision
  function debtOfExact(address account) external view returns (uint256);

  /// @notice Retrieves the current interest rate for an asset
  /// @return The interest rate in yield-per-second, scaled by 10**27
  function interestRate() external view returns (uint256);

  /// @notice Retrieves the current interest rate accumulator for an asset
  /// @return An opaque accumulator that increases as interest is accrued
  function interestAccumulator() external view returns (uint256);

  /// @notice Returns an address of the sidecar DToken
  /// @return The address of the DToken
  function dToken() external view returns (address);

  /// @notice Transfer underlying tokens from the vault to the sender, and increase sender's debt
  /// @param amount Amount of assets to borrow (use max uint256 for all available tokens)
  /// @param receiver Account receiving the borrowed tokens
  /// @return Amount of assets borrowed
  function borrow(uint256 amount, address receiver) external returns (uint256);

  /// @notice Transfer underlying tokens from the sender to the vault, and decrease receiver's debt
  /// @param amount Amount of debt to repay in assets (use max uint256 for full debt)
  /// @param receiver Account holding the debt to be repaid
  /// @return Amount of assets repaid
  function repay(uint256 amount, address receiver) external returns (uint256);

  /// @notice Pay off liability with shares ("self-repay")
  /// @param amount In asset units (use max uint256 to repay the debt in full or up to the available deposit)
  /// @param receiver Account to remove debt from by burning sender's shares
  /// @return shares Amount of shares burned
  /// @return debt Amount of debt removed in assets
  /// @dev Equivalent to withdrawing and repaying, but no assets are needed to be present in the vault
  /// @dev Contrary to a regular `repay`, if account is unhealthy, the repay amount must bring the account back to
  /// health, or the operation will revert during account status check
  function repayWithShares(uint256 amount, address receiver)
    external
    returns (uint256 shares, uint256 debt);

  /// @notice Take over debt from another account
  /// @param amount Amount of debt in asset units (use max uint256 for all the account's debt)
  /// @param from Account to pull the debt from
  /// @dev Due to internal debt precision accounting, the liability reported on either or both accounts after
  /// calling `pullDebt` may not match the `amount` requested precisely
  function pullDebt(uint256 amount, address from) external;

  /// @notice Request a flash-loan. A onFlashLoan() callback in msg.sender will be invoked, which must repay the loan
  /// to the main Euler address prior to returning.
  /// @param amount In asset units
  /// @param data Passed through to the onFlashLoan() callback, so contracts don't need to store transient data in
  /// storage
  function flashLoan(uint256 amount, bytes calldata data) external;

  /// @notice Updates interest accumulator and totalBorrows, credits reserves, re-targets interest rate, and logs
  /// vault status
  function touch() external;
}

/// @title IGovernance
/// @notice Interface of the EVault's Governance module
interface IGovernance {
  /// @notice Retrieves the address of the governor
  /// @return The governor address
  function governorAdmin() external view returns (address);

  /// @notice Retrieves address of the governance fee receiver
  /// @return The fee receiver address
  function feeReceiver() external view returns (address);

  /// @notice Retrieves the interest fee in effect for the vault
  /// @return Amount of interest that is redirected as a fee, as a fraction scaled by 1e4
  function interestFee() external view returns (uint16);

  /// @notice Looks up an asset's currently configured interest rate model
  /// @return Address of the interest rate contract or address zero to indicate 0% interest
  function interestRateModel() external view returns (address);

  /// @notice Retrieves the ProtocolConfig address
  /// @return The protocol config address
  function protocolConfigAddress() external view returns (address);

  /// @notice Retrieves the protocol fee share
  /// @return A percentage share of fees accrued belonging to the protocol, in 1e4 scale
  function protocolFeeShare() external view returns (uint256);

  /// @notice Retrieves the address which will receive protocol's fees
  /// @notice The protocol fee receiver address
  function protocolFeeReceiver() external view returns (address);

  /// @notice Retrieves supply and borrow caps in AmountCap format
  /// @return supplyCap The supply cap in AmountCap format
  /// @return borrowCap The borrow cap in AmountCap format
  function caps() external view returns (uint16 supplyCap, uint16 borrowCap);

  /// @notice Retrieves the borrow LTV of the collateral, which is used to determine if the account is healthy during
  /// account status checks.
  /// @param collateral The address of the collateral to query
  /// @return Borrowing LTV in 1e4 scale
  function LTVBorrow(address collateral) external view returns (uint16);

  /// @notice Retrieves the current liquidation LTV, which is used to determine if the account is eligible for
  /// liquidation
  /// @param collateral The address of the collateral to query
  /// @return Liquidation LTV in 1e4 scale
  function LTVLiquidation(address collateral) external view returns (uint16);

  /// @notice Retrieves LTV configuration for the collateral
  /// @param collateral Collateral asset
  /// @return borrowLTV The current value of borrow LTV for originating positions
  /// @return liquidationLTV The value of fully converged liquidation LTV
  /// @return initialLiquidationLTV The initial value of the liquidation LTV, when the ramp began
  /// @return targetTimestamp The timestamp when the liquidation LTV is considered fully converged
  /// @return rampDuration The time it takes for the liquidation LTV to converge from the initial value to the fully
  /// converged value
  function LTVFull(address collateral)
    external
    view
    returns (
      uint16 borrowLTV,
      uint16 liquidationLTV,
      uint16 initialLiquidationLTV,
      uint48 targetTimestamp,
      uint32 rampDuration
    );

  /// @notice Retrieves a list of collaterals with configured LTVs
  /// @return List of asset collaterals
  /// @dev Returned assets could have the ltv disabled (set to zero)
  function LTVList() external view returns (address[] memory);

  /// @notice Retrieves the maximum liquidation discount
  /// @return The maximum liquidation discount in 1e4 scale
  /// @dev The default value, which is zero, is deliberately bad, as it means there would be no incentive to liquidate
  /// unhealthy users. The vault creator must take care to properly select the limit, given the underlying and
  /// collaterals used.
  function maxLiquidationDiscount() external view returns (uint16);

  /// @notice Retrieves liquidation cool-off time, which must elapse after successful account status check before
  /// account can be liquidated
  /// @return The liquidation cool off time in seconds
  function liquidationCoolOffTime() external view returns (uint16);

  /// @notice Retrieves a hook target and a bitmask indicating which operations call the hook target
  /// @return hookTarget Address of the hook target contract
  /// @return hookedOps Bitmask with operations that should call the hooks. See Constants.sol for a list of operations
  function hookConfig() external view returns (address hookTarget, uint32 hookedOps);

  /// @notice Retrieves a bitmask indicating enabled config flags
  /// @return Bitmask with config flags enabled
  function configFlags() external view returns (uint32);

  /// @notice Address of EthereumVaultConnector contract
  /// @return The EVC address
  function EVC() external view returns (address);

  /// @notice Retrieves a reference asset used for liquidity calculations
  /// @return The address of the reference asset
  function unitOfAccount() external view returns (address);

  /// @notice Retrieves the address of the oracle contract
  /// @return The address of the oracle
  function oracle() external view returns (address);

  /// @notice Retrieves the Permit2 contract address
  /// @return The address of the Permit2 contract
  function permit2Address() external view returns (address);

  /// @notice Splits accrued fees balance according to protocol fee share and transfers shares to the governor fee
  /// receiver and protocol fee receiver
  function convertFees() external;

  /// @notice Set a new governor address
  /// @param newGovernorAdmin The new governor address
  /// @dev Set to zero address to renounce privileges and make the vault non-governed
  function setGovernorAdmin(address newGovernorAdmin) external;

  /// @notice Set a new governor fee receiver address
  /// @param newFeeReceiver The new fee receiver address
  function setFeeReceiver(address newFeeReceiver) external;

  /// @notice Set a new LTV config
  /// @param collateral Address of collateral to set LTV for
  /// @param borrowLTV New borrow LTV, for assessing account's health during account status checks, in 1e4 scale
  /// @param liquidationLTV New liquidation LTV after ramp ends in 1e4 scale
  /// @param rampDuration Ramp duration in seconds
  function setLTV(address collateral, uint16 borrowLTV, uint16 liquidationLTV, uint32 rampDuration)
    external;

  /// @notice Set a new maximum liquidation discount
  /// @param newDiscount New maximum liquidation discount in 1e4 scale
  /// @dev If the discount is zero (the default), the liquidators will not be incentivized to liquidate unhealthy
  /// accounts
  function setMaxLiquidationDiscount(uint16 newDiscount) external;

  /// @notice Set a new liquidation cool off time, which must elapse after successful account status check before
  /// account can be liquidated
  /// @param newCoolOffTime The new liquidation cool off time in seconds
  /// @dev Setting cool off time to zero allows liquidating the account in the same block as the last successful
  /// account status check
  function setLiquidationCoolOffTime(uint16 newCoolOffTime) external;

  /// @notice Set a new interest rate model contract
  /// @param newModel The new IRM address
  /// @dev If the new model reverts, perhaps due to governor error, the vault will silently use a zero interest
  /// rate. Governor should make sure the new interest rates are computed as expected.
  function setInterestRateModel(address newModel) external;

  /// @notice Set a new hook target and a new bitmap indicating which operations should call the hook target.
  /// Operations are defined in Constants.sol.
  /// @param newHookTarget The new hook target address. Use address(0) to simply disable hooked operations
  /// @param newHookedOps Bitmask with the new hooked operations
  /// @dev All operations are initially disabled in a newly created vault. The vault creator must set their
  /// own configuration to make the vault usable
  function setHookConfig(address newHookTarget, uint32 newHookedOps) external;

  /// @notice Set new bitmap indicating which config flags should be enabled. Flags are defined in Constants.sol
  /// @param newConfigFlags Bitmask with the new config flags
  function setConfigFlags(uint32 newConfigFlags) external;

  /// @notice Set new supply and borrow caps in AmountCap format
  /// @param supplyCap The new supply cap in AmountCap fromat
  /// @param borrowCap The new borrow cap in AmountCap fromat
  function setCaps(uint16 supplyCap, uint16 borrowCap) external;

  /// @notice Set a new interest fee
  /// @param newFee The new interest fee
  function setInterestFee(uint16 newFee) external;
}

/// @title IEVault
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Interface of the EVault, an EVC enabled lending vault
interface IEVault is IERC4626, IBorrowing, IGovernance {
  /// @notice Fetch address of the `Initialize` module
  function MODULE_INITIALIZE() external view returns (address);
  /// @notice Fetch address of the `Token` module
  function MODULE_TOKEN() external view returns (address);
  /// @notice Fetch address of the `Vault` module
  function MODULE_VAULT() external view returns (address);
  /// @notice Fetch address of the `Borrowing` module
  function MODULE_BORROWING() external view returns (address);
  /// @notice Fetch address of the `Liquidation` module
  function MODULE_LIQUIDATION() external view returns (address);
  /// @notice Fetch address of the `RiskManager` module
  function MODULE_RISKMANAGER() external view returns (address);
  /// @notice Fetch address of the `BalanceForwarder` module
  function MODULE_BALANCE_FORWARDER() external view returns (address);
  /// @notice Fetch address of the `Governance` module
  function MODULE_GOVERNANCE() external view returns (address);
}
