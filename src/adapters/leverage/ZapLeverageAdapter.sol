// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IKSSafeAccountHub} from '../../interfaces/IKSSafeAccountHub.sol';
import {IFlashLoanReceiver} from '../../interfaces/adapters/flashloan/IFlashLoanReceiver.sol';
import {ILendingActionAdapter} from '../../interfaces/adapters/lending/ILendingActionAdapter.sol';
import {IZapLeverageAdapter} from '../../interfaces/adapters/leverage/IZapLeverageAdapter.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';

import {Common} from 'ks-common-sc/src/base/Common.sol';
import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';

/// @title ZapLeverageAdapter
/// @notice Increases or decreases the leverage of a lending position of a Safe account inside a
/// flash loan of the flash loan adapter, which delegatecalls it as the target of the loan. The Safe
/// delegatecalls `modifyLeverage` from a call of KSSafeAccountHub.
/// @dev The owner limits are checked on the amounts of the lending call before it is made, and they
/// bound the effect of the solver data on the position. The amount borrowed on an increase and the
/// amount withdrawn on a decrease is the amount that the flash loan adapter lacks to repay the
/// loan. The lending call uses the whole balance of the Safe of the collateral token on an
/// increase, and of the debt token on a decrease, minus 1 wei. The swap target runs as the flash
/// loan adapter, so a call that it makes to KSSafeAccountHub makes the later call of
/// {receiveFlashLoan} to it revert with `SafeAlreadyExecuted`.
contract ZapLeverageAdapter is IZapLeverageAdapter, ImmutableState {
  using TokenHelper for address;
  using CommonLibrary for *;
  using Address for address;
  using CalldataDecoder for bytes;

  /// @dev Arc's native USDC (18 decimals) and its ERC20 counterpart (6 decimals) share the
  /// same underlying balance. Amounts must be rescaled by this factor whenever a token is
  /// relabeled between the native address and `address(WETH)` for the (external) lending
  /// adapter call, since that call is interpreted per-token using standard decimals.
  uint256 internal constant NATIVE_TO_USDC_DECIMALS_SCALE = 1e12;

  /// @dev KSSafeAccountHub, the only account allowed to call {modifyLeverage}
  address internal immutable SAFE_ACCOUNT_HUB;

  /// @dev Flash loan adapter that the step repays and that delegatecalls {receiveFlashLoan}
  address internal immutable FLASH_LOAN_ADAPTER;

  /**
   * @param _WETH The wrapped native token
   * @param safeAccountHub The KSSafeAccountHub allowed to call {modifyLeverage}
   * @param flashLoanAdapter The flash loan adapter that delegatecalls {receiveFlashLoan} and
   * receives the amount
   */
  constructor(address _WETH, address safeAccountHub, address flashLoanAdapter)
    ImmutableState(_WETH)
    checkAddress(safeAccountHub)
    checkAddress(flashLoanAdapter)
  {
    SAFE_ACCOUNT_HUB = safeAccountHub;
    FLASH_LOAN_ADAPTER = flashLoanAdapter;
  }

  /// @inheritdoc IZapLeverageAdapter
  function withdrawTokens(address[] calldata tokens, address recipient) external {
    IKSSafeAccountHub safeAccountHub = IKSSafeAccountHub(SAFE_ACCOUNT_HUB);
    uint256 tokenId = safeAccountHub.safeToTokenId(address(this));
    address holder = safeAccountHub.ownerOf(tokenId);
    require(msg.sender == holder, UnauthorizedCaller(msg.sender));

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].safeTransfer(recipient, tokens[i].selfBalance());
    }
  }

  /**
   * @inheritdoc IFlashLoanReceiver
   * @dev `ownerData` is `abi.encode(address safe, address owner, bytes leverageData)`, with
   * `leverageData` as in {modifyLeverage}. `solverData` is empty when the loan is not swapped, or
   * `abi.encode(LeverageSwap)`.
   */
  function receiveFlashLoan(
    address[] calldata tokens,
    uint256[] calldata owedAmounts,
    bytes calldata ownerData,
    bytes calldata solverData
  ) external {
    // It runs only as a delegatecall of the flash loan adapter
    require(address(this) == FLASH_LOAN_ADAPTER, NotFlashLoanAdapter());

    address safe = ownerData.decodeAddress(0);
    address owner = ownerData.decodeAddress(1);
    bytes calldata leverageData = ownerData.decodeBytes(2);

    // The loan token is the first token of the loan
    address loanToken = tokens[0];
    uint256 owed = owedAmounts[0];

    // 1. Swap the loan when the solver data is not empty. The swap sends its output to the Safe.
    if (solverData.length != 0) {
      LeverageSwap calldata swap;
      assembly ('memory-safe') {
        swap := add(solverData.offset, calldataload(solverData.offset))
      }
      _swapLoan(loanToken, swap);
    }

    // 2. Call KSSafeAccountHub, whose Safe delegatecalls `modifyLeverage` of the deployed adapter and
    // transfers back the amount that the loan token balance lacks to repay the loan. In this
    // context `address(this)` is the flash loan adapter, so the target is `original`.
    uint256 loanBalance = loanToken.selfBalance();
    uint256 remaining = Math.saturatingSub(owed, loanBalance);
    bytes memory leverageCallData =
      abi.encodeCall(this.modifyLeverage, (leverageData, loanToken, remaining, owner));
    IKSSafeAccountHub(SAFE_ACCOUNT_HUB).execute(safe, original, leverageCallData, owner);
  }

  /// @inheritdoc IZapLeverageAdapter
  function modifyLeverage(
    bytes calldata leverageData,
    address loanToken,
    uint256 amount,
    address owner
  ) external {
    require(msg.sender == SAFE_ACCOUNT_HUB, UnauthorizedCaller(msg.sender));

    // The first byte is the action type and the rest the parameters of the action
    ActionType actionType = ActionType(uint8(leverageData[0]));
    bytes calldata actionParams = leverageData[1:];

    if (actionType == ActionType.INCREASE_LEVERAGE) {
      IncreaseLeverageParams calldata params;
      assembly ('memory-safe') {
        params := add(actionParams.offset, calldataload(actionParams.offset))
      }
      _increaseLeverage(loanToken, amount, params);
    } else {
      DecreaseLeverageParams calldata params;
      assembly ('memory-safe') {
        params := add(actionParams.offset, calldataload(actionParams.offset))
      }
      _decreaseLeverage(loanToken, amount, params);

      // The collateral and debt balances left in the Safe are transferred to the owner
      _sweep(params.collateralToken, owner, params.minSweepAmounts.value0());
      _sweep(params.debtToken, owner, params.minSweepAmounts.value1());
    }
  }

  /// @dev Transfers the balance less 1 wei of `token` to `owner` when that amount is not zero and
  /// is at least `minAmount`. Any other balance stays in the Safe.
  function _sweep(address token, address owner, uint256 minAmount) internal {
    uint256 amount = token.selfBalanceMinusOne();
    if (amount != 0 && amount >= minAmount) token.safeTransfer(owner, amount);
  }

  /// @dev Swaps the loan through the swap target. A native loan token is not approved: the whole
  /// native balance is sent as the value of the call.
  function _swapLoan(address loanToken, LeverageSwap calldata swap) internal {
    (bool approvalFlag, address target) = swap.target.unpack();
    bool nativeInput = loanToken.isNative();
    if (approvalFlag && !nativeInput) {
      loanToken.forceApproveInf(target);
    }

    if (nativeInput) {
      // forge-lint: disable-next-line(arbitrary-send-eth)
      target.functionCallWithValue(swap.data, loanToken.selfBalance());
    } else {
      target.functionCall(swap.data);
    }
  }

  /// @dev Supplies the collateral balance and borrows the debt token for `amount` of the loan
  /// token, after checking the amounts against `minCollateralDeposit` and `maxDebtBorrow`, then
  /// transfers `amount` to the flash loan adapter. The loan token is the debt token or its native or
  /// wrapped form.
  function _increaseLeverage(
    address loanToken,
    uint256 amount,
    IncreaseLeverageParams calldata params
  ) internal {
    address collateralToken = params.collateralToken;
    address debtToken = params.debtToken;
    uint256 borrowAmount = _lendingAmount(loanToken, debtToken, amount);

    // The balance of the Safe is held in the form of the collateral token before it is supplied
    _convertBalanceTo(collateralToken);
    uint256 collateralAmount = collateralToken.selfBalanceMinusOne();
    require(
      collateralAmount >= params.minCollateralDeposit,
      LeverageInsufficientCollateralDeposit(collateralAmount, params.minCollateralDeposit)
    );
    require(
      borrowAmount <= params.maxDebtBorrow,
      LeverageExcessiveDebtBorrow(borrowAmount, params.maxDebtBorrow)
    );

    bytes memory actionCallData = abi.encodeCall(
      ILendingActionAdapter.supplyCollateralAndBorrow,
      (
        params.lendingContext,
        collateralToken,
        collateralAmount,
        debtToken,
        borrowAmount,
        address(this)
      )
    );
    params.lendingAdapter.functionDelegateCall(actionCallData);

    // The borrowed debt token is converted to the loan token that repays the flash loan
    if (debtToken != loanToken) _convertBalanceTo(loanToken);
    loanToken.safeTransfer(FLASH_LOAN_ADAPTER, amount);
  }

  /// @dev Repays the debt balance and withdraws the collateral token for `amount` of the loan token,
  /// after checking the amounts against `minDebtRepay` and `maxCollateralWithdraw`, then transfers
  /// `amount` to the flash loan adapter. The loan token is the collateral token or its native or
  /// wrapped form.
  function _decreaseLeverage(
    address loanToken,
    uint256 amount,
    DecreaseLeverageParams calldata params
  ) internal {
    address collateralToken = params.collateralToken;
    address debtToken = params.debtToken;
    bool withdrawFull = params.withdrawFull;
    uint256 withdrawAmount =
      withdrawFull ? type(uint256).max : _lendingAmount(loanToken, collateralToken, amount);

    // The balance of the Safe is held in the form of the debt token before it is repaid
    _convertBalanceTo(debtToken);
    uint256 repayAmount = withdrawFull ? type(uint256).max : debtToken.selfBalanceMinusOne();
    require(
      repayAmount >= params.minDebtRepay,
      LeverageInsufficientDebtRepay(repayAmount, params.minDebtRepay)
    );
    require(
      withdrawAmount <= params.maxCollateralWithdraw,
      LeverageExcessiveCollateralWithdraw(withdrawAmount, params.maxCollateralWithdraw)
    );

    bytes memory actionCallData = abi.encodeCall(
      ILendingActionAdapter.repayAndWithdrawCollateral,
      (
        params.lendingContext,
        debtToken,
        repayAmount,
        collateralToken,
        withdrawAmount,
        address(this)
      )
    );
    params.lendingAdapter.functionDelegateCall(actionCallData);

    // The withdrawn collateral token is converted to the loan token that repays the flash loan
    if (collateralToken != loanToken) _convertBalanceTo(loanToken);
    loanToken.safeTransfer(FLASH_LOAN_ADAPTER, amount);
  }

  /// @dev Returns `amount` of `loanToken` in units of `lendingToken`, which must be the same token
  /// or its native or wrapped form. On an Arc-like chain the amount is scaled between the 18
  /// decimals of the native token and the 6 decimals of its ERC20, rounding up toward the ERC20.
  function _lendingAmount(address loanToken, address lendingToken, uint256 amount)
    internal
    view
    returns (uint256)
  {
    if (loanToken == lendingToken) return amount;

    bool nativeToWrapped = loanToken.isNative() && lendingToken == address(WETH);
    bool wrappedToNative = loanToken == address(WETH) && lendingToken.isNative();
    require(nativeToWrapped || wrappedToNative, LoanTokenMismatch(loanToken, lendingToken));

    if (!IS_ARC_CHAIN_LIKE) return amount;
    return nativeToWrapped
      ? Math.ceilDiv(amount, NATIVE_TO_USDC_DECIMALS_SCALE)
      : amount * NATIVE_TO_USDC_DECIMALS_SCALE;
  }

  /// @dev Converts the balance of the counterpart form into `token`: wraps the native balance for
  /// WETH and unwraps WETH for the native token. An Arc-like chain shares one balance between the
  /// two and converts nothing.
  function _convertBalanceTo(address token) internal {
    if (IS_ARC_CHAIN_LIKE) return;
    if (token.isNative()) {
      WETH.unwrapWETH();
    } else if (token == address(WETH)) {
      WETH.wrapETH();
    }
  }
}
