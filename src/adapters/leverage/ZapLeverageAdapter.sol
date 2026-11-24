// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {IKSSafeAccountHub} from '../../interfaces/IKSSafeAccountHub.sol';
import {IFlashLoanAdapter} from '../../interfaces/adapters/flashloan/IFlashLoanAdapter.sol';
import {IFlashLoanReceiver} from '../../interfaces/adapters/flashloan/IFlashLoanReceiver.sol';
import {ILendingActionAdapter} from '../../interfaces/adapters/lending/ILendingActionAdapter.sol';
import {IZapLeverageAdapter} from '../../interfaces/adapters/leverage/IZapLeverageAdapter.sol';

import {ImmutableState} from '../../base/ImmutableState.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {ContractCall} from '../../types/ContractCall.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

/// @title ZapLeverageAdapter
/// @notice Increases or decreases the leverage of a lending position of a Safe account through a
/// flash loan. The allowance hub v2 calls `execute` in an order, and the Safe delegatecalls
/// `receiveFlashLoan` in the flash loan callback.
/// @dev `execute` passes the swap to the flash loan adapter, which runs it in the flash loan
/// callback with the loaned token before the Safe delegatecalls `receiveFlashLoan`. The swap target
/// comes from the owner parameters, and the swap calldata comes from the solver data. The solver
/// data is untrusted, and `minSwapAmountOut` bounds the swap. `receiveFlashLoan` checks the owner
/// limits on the amounts of the lending call before making it, which bound the effect of the solver
/// data on the position. In `receiveFlashLoan`, the lending call uses the whole balance of the Safe
/// of the collateral token on an increase, and of the debt token on a decrease, minus 1 wei.
contract ZapLeverageAdapter is IZapLeverageAdapter, ImmutableState {
  using TokenHelper for address;
  using CommonLibrary for *;
  using Address for address;

  /// @dev Arc's native USDC (18 decimals) and its ERC20 counterpart (6 decimals) share the
  /// same underlying balance. Amounts must be rescaled by this factor whenever a token is
  /// relabeled between the native address and `address(WETH)` for the (external) lending
  /// adapter call, since that call is interpreted per-token using standard decimals.
  uint256 internal constant NATIVE_TO_USDC_DECIMALS_SCALE = 1e12;

  /// @inheritdoc IZapLeverageAdapter
  address public immutable ALLOWANCE_HUB;

  /// @inheritdoc IZapLeverageAdapter
  address public immutable SAFE_ACCOUNT_HUB;

  /// @inheritdoc IZapLeverageAdapter
  address public immutable FLASH_LOAN_ADAPTER;

  constructor(address _WETH, address allowanceHub, address safeAccountHub, address flashLoanAdapter)
    ImmutableState(_WETH)
  {
    ALLOWANCE_HUB = allowanceHub;
    SAFE_ACCOUNT_HUB = safeAccountHub;
    FLASH_LOAN_ADAPTER = flashLoanAdapter;
  }

  /**
   * @inheritdoc IAHV2Callee
   * @dev `ownerData` is the ABI-encoded {LeverageParams}. `solverData` is the calldata of
   * the swap. It returns no data.
   */
  function execute(bytes calldata ownerData, bytes calldata solverData)
    external
    payable
    returns (bytes memory)
  {
    require(msg.sender == ALLOWANCE_HUB, UnauthorizedCaller(msg.sender));

    LeverageParams calldata params;
    assembly ('memory-safe') {
      params := add(ownerData.offset, calldataload(ownerData.offset))
    }

    IFlashLoanAdapter.SafeAccountSwap memory swap = _leverageSwap(params, solverData);

    _leverage(params, swap);

    return '';
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
   * @dev The Safe delegatecalls this function in the flash loan callback, so it runs in the
   * context of the Safe, and `msg.sender` is the flash loan adapter. `amounts[0]` is the amount
   * of `tokens[0]` the Safe returns to the flash loan adapter. `data` is the ABI-encoded
   * {LeverageCallbackParams}.
   */
  function receiveFlashLoan(
    address[] calldata tokens,
    uint256[] calldata amounts,
    bytes calldata data
  ) external payable {
    require(msg.sender == FLASH_LOAN_ADAPTER, UnauthorizedCaller(msg.sender));

    LeverageCallbackParams calldata params;
    assembly ('memory-safe') {
      params := add(data.offset, calldataload(data.offset))
    }

    if (params.actionType == ActionType.INCREASE_LEVERAGE) {
      _supplyAndBorrow(
        tokens[0],
        amounts[0],
        params.lendingAdapter,
        params.lendingContext,
        params.collateralToken,
        params.wrapOrUnwrap,
        params.minCollateralDeposit,
        params.maxDebtBorrow
      );
    } else {
      _repayAndWithdraw(
        tokens[0],
        amounts[0],
        params.lendingAdapter,
        params.lendingContext,
        params.debtToken,
        params.wrapOrUnwrap,
        params.withdrawFull,
        params.minDebtRepay,
        params.maxCollateralWithdraw
      );
    }

    if (!IS_ARC_CHAIN_LIKE && params.wrapOrUnwrap) {
      if (tokens[0].isNative()) {
        WETH.unwrapWETH();
      } else if (tokens[0] == address(WETH)) {
        WETH.wrapETH();
      }
    }

    tokens[0].safeTransfer(msg.sender, amounts[0]);
  }

  /// @dev Resolves the swap from the owner parameters and the solver data. No swap runs when the
  /// owner target or the swap amount is zero. Otherwise the swap calls the owner target with the
  /// solver data as the calldata.
  function _leverageSwap(LeverageParams calldata params, bytes calldata solverData)
    internal
    pure
    returns (IFlashLoanAdapter.SafeAccountSwap memory swap)
  {
    if (params.swapTarget != address(0) && params.swapAmountIn != 0) {
      require(solverData.length != 0, LeverageSwapMissing());
      require(params.minSwapAmountOut != 0, LeverageSwapUnbounded());
      swap.target = params.swapTarget;
      swap.approveMax = params.swapApproveMax;
      swap.data = solverData;
    }

    swap.tokenOut = params.swapTokenOut;
    swap.amountIn = params.swapAmountIn;
    swap.minAmountOut = params.minSwapAmountOut;
  }

  /// @dev Executes the flash loan from the Safe through KSSafeAccountHub. The flash loan adapter
  /// runs the swap, then the Safe delegatecalls `receiveFlashLoan` of this contract.
  function _leverage(LeverageParams calldata params, IFlashLoanAdapter.SafeAccountSwap memory swap)
    internal
  {
    LeverageCallbackParams memory callbackParams = LeverageCallbackParams({
      actionType: params.actionType,
      wrapOrUnwrap: params.wrapOrUnwrap,
      withdrawFull: params.withdrawFull,
      lendingAdapter: params.lendingAdapter,
      lendingContext: params.lendingContext,
      collateralToken: params.collateralToken,
      debtToken: params.debtToken,
      minCollateralDeposit: params.minCollateralDeposit,
      maxDebtBorrow: params.maxDebtBorrow,
      minDebtRepay: params.minDebtRepay,
      maxCollateralWithdraw: params.maxCollateralWithdraw
    });

    bytes memory callbackData = abi.encode(callbackParams);
    bytes memory receiverData = abi.encode(address(this), callbackData, swap);
    uint256 flashLoanContext = (uint256(params.flashLoanSource) << 8)
      | uint256(IFlashLoanAdapter.ReceiverType.SAFE_ACCOUNT_SWAP);
    bytes memory flashLoanCall = abi.encodeCall(
      IFlashLoanAdapter.flashLoan, (flashLoanContext, params.flashLoanParams, receiverData)
    );

    ContractCall[] memory calls = new ContractCall[](1);
    calls[0] =
      ContractCall({target: FLASH_LOAN_ADAPTER, data: flashLoanCall, isDelegateCall: false});

    address[] memory modules = new address[](1);
    modules[0] = FLASH_LOAN_ADAPTER;

    IKSSafeAccountHub(SAFE_ACCOUNT_HUB).execute(params.safe, modules, calls, params.recipient);
  }

  /// @dev Supplies the collateral balance and borrows `flashLoanAmount` of the debt token, after
  /// checking the amounts against `minCollateralDeposit` and `maxDebtBorrow`
  function _supplyAndBorrow(
    address debtToken,
    uint256 flashLoanAmount,
    address lendingAdapter,
    bytes calldata lendingContext,
    address collateralToken,
    bool wrapOrUnwrap,
    uint256 minCollateralDeposit,
    uint256 maxDebtBorrow
  ) internal {
    if (wrapOrUnwrap) {
      if (debtToken.isNative()) {
        debtToken = address(WETH);
        if (IS_ARC_CHAIN_LIKE) {
          flashLoanAmount =
            (flashLoanAmount + NATIVE_TO_USDC_DECIMALS_SCALE - 1) / NATIVE_TO_USDC_DECIMALS_SCALE;
        }
      } else if (debtToken == address(WETH)) {
        debtToken = TokenHelper.NATIVE_ADDRESS;
        if (IS_ARC_CHAIN_LIKE) flashLoanAmount *= NATIVE_TO_USDC_DECIMALS_SCALE;
      }

      if (collateralToken.isNative()) {
        WETH.unwrapWETH();
      }
    }

    uint256 collateralAmount = collateralToken.selfBalanceMinusOne();
    require(
      collateralAmount >= minCollateralDeposit,
      LeverageInsufficientCollateralDeposit(collateralAmount, minCollateralDeposit)
    );
    require(
      flashLoanAmount <= maxDebtBorrow, LeverageExcessiveDebtBorrow(flashLoanAmount, maxDebtBorrow)
    );
    bytes memory actionCallData = abi.encodeCall(
      ILendingActionAdapter.supplyCollateralAndBorrow,
      (lendingContext, collateralToken, collateralAmount, debtToken, flashLoanAmount, address(this))
    );
    lendingAdapter.functionDelegateCall(actionCallData);
  }

  /// @dev Repays the debt balance and withdraws `flashLoanAmount` of the collateral token, after
  /// checking the amounts against `minDebtRepay` and `maxCollateralWithdraw`
  function _repayAndWithdraw(
    address collateralToken,
    uint256 flashLoanAmount,
    address lendingAdapter,
    bytes calldata lendingContext,
    address debtToken,
    bool wrapOrUnwrap,
    bool withdrawFull,
    uint256 minDebtRepay,
    uint256 maxCollateralWithdraw
  ) internal {
    if (wrapOrUnwrap) {
      if (collateralToken.isNative()) {
        collateralToken = address(WETH);
        if (IS_ARC_CHAIN_LIKE) {
          flashLoanAmount =
            (flashLoanAmount + NATIVE_TO_USDC_DECIMALS_SCALE - 1) / NATIVE_TO_USDC_DECIMALS_SCALE;
        }
      } else if (collateralToken == address(WETH)) {
        collateralToken = TokenHelper.NATIVE_ADDRESS;
        if (IS_ARC_CHAIN_LIKE) flashLoanAmount *= NATIVE_TO_USDC_DECIMALS_SCALE;
      }

      if (debtToken.isNative()) {
        WETH.unwrapWETH();
      }
    }

    uint256 repayAmount = withdrawFull ? type(uint256).max : debtToken.selfBalanceMinusOne();
    uint256 withdrawAmount = withdrawFull ? type(uint256).max : flashLoanAmount;
    require(repayAmount >= minDebtRepay, LeverageInsufficientDebtRepay(repayAmount, minDebtRepay));
    require(
      withdrawAmount <= maxCollateralWithdraw,
      LeverageExcessiveCollateralWithdraw(withdrawAmount, maxCollateralWithdraw)
    );
    bytes memory actionCallData = abi.encodeCall(
      ILendingActionAdapter.repayAndWithdrawCollateral,
      (lendingContext, debtToken, repayAmount, collateralToken, withdrawAmount, address(this))
    );
    lendingAdapter.functionDelegateCall(actionCallData);
  }
}
