// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanAdapter {
  /// @notice Thrown when the execution fails
  error SafeModuleExecutionFailed(bytes reason);

  /// @notice Thrown when the flash loan source is invalid
  error InvalidFlashLoanSource(FlashLoanSource source);

  /// @notice Thrown when `flashLoan` runs through a delegatecall
  error DelegateCallNotAllowed();

  /// @notice Thrown when `flashLoan` is called while a flash loan runs
  error FlashLoanInProgress();

  /// @notice Thrown when a flash loan callback runs while no flash loan waits for its callback
  error UnexpectedFlashLoanCallback();

  /// @notice Thrown when the call to the swap target fails
  error SafeAccountSwapFailed();

  /// @notice Thrown when the swap increases the Safe balance of the output token by less than the
  /// minimum
  error SafeAccountSwapInsufficientOutput(uint256 amountOut, uint256 minAmountOut);

  /// @notice The list of flash loan sources
  enum FlashLoanSource {
    AAVE_V3,
    ERC3156,
    MORPHO_BLUE,
    UNISWAP_V3,
    UNISWAP_V4,
    PANCAKE_INFINITY,
    EULER_V2
  }

  /// @notice The list of receiver types
  enum ReceiverType {
    /// The caller receives the loan and its `receiveFlashLoan` is called with the data
    NORMAL,
    /// The caller is a Safe account that delegatecalls an executor with the loan
    SAFE_ACCOUNT,
    /// As `SAFE_ACCOUNT`, with a swap of the first loaned token before the executor runs
    SAFE_ACCOUNT_SWAP
  }

  /**
   * @notice The swap of the first loaned token that the flash loan adapter runs before the Safe
   * account receiver is called
   * @param target The contract called with `data`, the zero address for no swap
   * @param approveMax Whether `target` is approved for the maximum amount of the first loaned
   * token, which is kept after the swap. Otherwise `target` is approved for `amountIn`, and the
   * approval is reset to zero after the swap.
   * @param tokenOut The token the swap outputs
   * @param amountIn The amount of the first loaned token the swap spends, as the approval or as the
   * native value sent to `target`
   * @param minAmountOut The minimum increase of the balance of `tokenOut` of the Safe account
   * @param data The calldata of the swap
   */
  struct SafeAccountSwap {
    address target;
    bool approveMax;
    address tokenOut;
    uint256 amountIn;
    uint256 minAmountOut;
    bytes data;
  }

  /**
   * @notice Takes a flash loan for the caller
   * @dev With the `NORMAL` receiver type, `data` is passed to `receiveFlashLoan` of the caller. With
   * the `SAFE_ACCOUNT` receiver type, the caller is a Safe account that enabled this contract as a
   * module, and `data` is `abi.encode(address executor, bytes executorData)`. The loaned tokens are
   * transferred to the Safe account, which delegatecalls `receiveFlashLoan` of `executor` with
   * `executorData` and the amounts owed. The `SAFE_ACCOUNT_SWAP` receiver type is the same, with
   * `data` equal to `abi.encode(address executor, bytes executorData, SafeAccountSwap swap)`. When
   * `swap.target` is not zero, the first loaned token stays in this contract for the swap, and the
   * first amount passed to the executor is the amount owed to the lender minus the balance of this
   * contract after the swap.
   * @param flashLoanContext The source of the flash loan shifted left by 8 bits, with the receiver
   * type in the low 8 bits
   * @param flashLoanParams The parameters of the flash loan, specific to the source
   * @param data The data for the receiver
   */
  function flashLoan(uint256 flashLoanContext, bytes calldata flashLoanParams, bytes calldata data)
    external
    payable;
}
