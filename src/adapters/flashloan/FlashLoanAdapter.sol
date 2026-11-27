// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {ImmutableState} from '../../base/ImmutableState.sol';
import {IFlashLoanAdapter} from '../../interfaces/adapters/flashloan/IFlashLoanAdapter.sol';
import {IFlashLoanReceiver} from '../../interfaces/adapters/flashloan/IFlashLoanReceiver.sol';

import {IPool} from '../../vendors/aave-v3/IPool.sol';
import {IEVault} from '../../vendors/euler-v2/IEVault.sol';
import {IMorpho} from '../../vendors/morpho/IMorpho.sol';
import {IUniswapV3Pool} from '../../vendors/uniswap-v3/IUniswapV3Pool.sol';

import {MASK_160_BITS} from '../../libraries/BitMask.sol';
import {CommonLibrary} from '../../libraries/CommonLibrary.sol';
import {BoolAddress} from '../../types/BoolAddress.sol';

import {
  CurrencySettler as PancakeInfinityCurrencySettler
} from '../../vendors/pancake-infinity/CurrencySettler.sol';
import {IVault as IPancakeInfinityVault} from '../../vendors/pancake-infinity/IVault.sol';

import {
  CurrencySettler as UniswapV4CurrencySettler
} from '../../vendors/uniswap-v4/CurrencySettler.sol';
import {IPoolManager} from '../../vendors/uniswap-v4/IPoolManager.sol';

import {IAHV2Callee} from 'ks-allowance-hub/src/interfaces/base/IAHV2Callee.sol';
import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';
import {
  IERC3156FlashBorrower,
  IERC3156FlashLender
} from 'openzeppelin-contracts/contracts/interfaces/IERC3156FlashLender.sol';
import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

/**
 * @title FlashLoanAdapter
 * @notice Takes a flash loan and delegatecalls a target while the loan is held, as a callee of
 * {AHV2ProxyCallee}
 * @dev The owner data names the target and its owner data. The solver data names the loan and the
 * solver data of the target. The target is delegatecalled in the context of this contract, holding
 * the loan, and must leave the amounts owed in it. The callbacks are accepted only from the
 * callback caller that the solver data names for the running flash loan.
 */
contract FlashLoanAdapter is IFlashLoanAdapter, ImmutableState {
  using CalldataDecoder for bytes;
  using TokenHelper for address;
  using CommonLibrary for *;
  using PancakeInfinityCurrencySettler for address;
  using UniswapV4CurrencySettler for address;
  using Address for address;

  /// @dev Phase while the call of a lender waits for its callback
  uint256 internal constant LOAN_STARTED = 1;

  /// @dev Phase from the callback until the call of the lender returns
  uint256 internal constant CALLBACK_RUNNING = 2;

  /// @dev Number of bits of the callback caller in `loanState`, below the phase
  uint256 internal constant PHASE_SHIFT = 160;

  /// @dev Proxy callee, the only account allowed to call {execute}
  address internal immutable PROXY_CALLEE;

  /// @dev Flash loan state of the transaction: the callback caller of the running flash loan in the
  /// low 160 bits, and the phase above them. The phase is 0 when no flash loan runs, `LOAN_STARTED` or
  /// `CALLBACK_RUNNING`.
  uint256 private transient loanState;

  /// @dev Requires that the caller is the proxy callee
  modifier onlyProxyCallee() {
    require(msg.sender == PROXY_CALLEE, UnauthorizedCaller(msg.sender));
    _;
  }

  /// @dev Requires that no flash loan runs, and clears the state after the function returns. The
  /// function sets the state through {_setLoanState}.
  modifier onlyOutsideFlashLoan() {
    (uint256 phase,) = _loanState();
    require(phase == 0, FlashLoanInProgress());
    _;
    _setLoanState(0, address(0));
  }

  /// @dev Requires the phase `LOAN_STARTED` and the callback caller of the flash loan as caller,
  /// then sets the phase to `CALLBACK_RUNNING`
  modifier onlyFlashLoanCallback() {
    (uint256 phase, address callbackCaller) = _loanState();
    require(phase == LOAN_STARTED, UnexpectedFlashLoanCallback());
    require(msg.sender == callbackCaller, UnauthorizedCallbackCaller(msg.sender));
    _setLoanState(CALLBACK_RUNNING, callbackCaller);
    _;
  }

  /**
   * @param _WETH The wrapped native token
   * @param proxyCallee The proxy callee allowed to call {execute}
   */
  constructor(address _WETH, address proxyCallee) ImmutableState(_WETH) checkAddress(proxyCallee) {
    PROXY_CALLEE = proxyCallee;
  }

  /**
   * @inheritdoc IAHV2Callee
   * @dev `ownerData` is `abi.encode(address target, bytes targetOwnerData)`. `solverData` is
   * `abi.encode(uint256 source, address callbackCaller, bytes flashLoanParams,
   * bytes targetSolverData)`: `source` is a {FlashLoanSource}, `callbackCaller` is the only account
   * whose callback is accepted, and the first word of `flashLoanParams` is the lender. In the
   * callback, `target` is delegatecalled through {IFlashLoanReceiver-receiveFlashLoan} with the loaned
   * tokens, the amounts owed, `targetOwnerData` and `targetSolverData`, and the loan is repaid
   * afterwards.
   * @return The empty bytes
   */
  function execute(bytes calldata ownerData, bytes calldata solverData)
    external
    payable
    onlyProxyCallee
    onlyOutsideFlashLoan
    returns (bytes memory)
  {
    // The callback caller is named by the solver, since it can differ from the lender
    address callbackCaller = solverData.decodeAddress(1);
    _setLoanState(LOAN_STARTED, callbackCaller);

    // The callback caller is part of the signed solver data, so the payload is not bound to a hash
    bytes memory payload = _buildPayload(ownerData, solverData);
    bytes calldata flashLoanParams = solverData.decodeBytes(2);

    // An out-of-range source reverts with a panic in the conversion
    FlashLoanSource source = FlashLoanSource(solverData.decodeUint256(0));
    _flashLoan(source, flashLoanParams, payload);

    (uint256 phase,) = _loanState();
    require(phase == CALLBACK_RUNNING, FlashLoanNotCalledBack());

    return '';
  }

  /// @dev Returns the phase and the callback caller of the flash loan
  function _loanState() internal view returns (uint256 phase, address callbackCaller) {
    uint256 state = loanState;
    phase = state >> PHASE_SHIFT;
    callbackCaller = address(uint160(state & MASK_160_BITS));
  }

  /// @dev Stores the phase and the callback caller of the flash loan
  function _setLoanState(uint256 phase, address callbackCaller) internal {
    loanState = (phase << PHASE_SHIFT) | uint160(callbackCaller);
  }

  /// @dev Returns the target and its data passed through the callback
  function _buildPayload(bytes calldata ownerData, bytes calldata solverData)
    internal
    pure
    returns (bytes memory)
  {
    address target = ownerData.decodeAddress(0);
    bytes calldata targetOwnerData = ownerData.decodeBytes(1);
    bytes calldata targetSolverData = solverData.decodeBytes(3);
    return abi.encode(target, targetOwnerData, targetSolverData);
  }

  /// @dev Starts the flash loan of the source with the lender-specific parameters
  function _flashLoan(FlashLoanSource source, bytes calldata flashLoanParams, bytes memory payload)
    internal
  {
    if (source == FlashLoanSource.AAVE_V3) {
      _handleAaveV3(flashLoanParams, payload);
    } else if (source == FlashLoanSource.ERC3156) {
      _handleERC3156(flashLoanParams, payload);
    } else if (source == FlashLoanSource.MORPHO_BLUE) {
      _handleMorphoBlue(flashLoanParams, payload);
    } else if (source == FlashLoanSource.UNISWAP_V3) {
      _handleUniswapV3(flashLoanParams, payload);
    } else if (source == FlashLoanSource.UNISWAP_V4) {
      _handleUniswapV4(flashLoanParams, payload);
    } else if (source == FlashLoanSource.PANCAKE_INFINITY) {
      _handlePancakeInfinity(flashLoanParams, payload);
    } else {
      _handleEuler(flashLoanParams, payload);
    }
  }

  function _handleAaveV3(bytes calldata flashLoanParams, bytes memory payload) internal {
    address pool = flashLoanParams.decodeAddress(0);
    uint256[] calldata amounts = flashLoanParams.decodeUint256Array(2);

    BoolAddress[] calldata tokenInfos;
    {
      (uint256 length, uint256 offset) = flashLoanParams.decodeLengthOffset(1);
      assembly ('memory-safe') {
        tokenInfos.length := length
        tokenInfos.offset := offset
      }
    }

    address[] memory tokens = new address[](tokenInfos.length);
    for (uint256 i = 0; i < tokenInfos.length; i++) {
      tokens[i] = tokenInfos[i].addressValue();
      if (tokenInfos[i].boolValue()) {
        tokens[i].forceApproveInf(pool);
      }
    }

    bytes memory callbackData = abi.encode(payload);
    IPool(pool)
      .flashLoan(
        address(this), tokens, amounts, new uint256[](tokens.length), address(0), callbackData, 0
      );
  }

  function _handleERC3156(bytes calldata flashLoanParams, bytes memory payload) internal {
    address lender = flashLoanParams.decodeAddress(0);
    BoolAddress tokenInfo = BoolAddress.wrap(flashLoanParams.decodeUint256(1));
    uint256 amount = flashLoanParams.decodeUint256(2);

    address token = tokenInfo.addressValue();
    if (tokenInfo.boolValue()) {
      token.forceApproveInf(lender);
    }

    bytes memory callbackData = abi.encode(payload);
    IERC3156FlashLender(lender)
      .flashLoan(IERC3156FlashBorrower(address(this)), token, amount, callbackData);
  }

  function _handleMorphoBlue(bytes calldata flashLoanParams, bytes memory payload) internal {
    address morpho = flashLoanParams.decodeAddress(0);
    BoolAddress tokenInfo = BoolAddress.wrap(flashLoanParams.decodeUint256(1));
    uint256 amount = flashLoanParams.decodeUint256(2);

    address token = tokenInfo.addressValue();
    if (tokenInfo.boolValue()) {
      token.forceApproveInf(morpho);
    }

    bytes memory callbackData = abi.encode(token, payload);
    IMorpho(morpho).flashLoan(token, amount, callbackData);
  }

  function _handleUniswapV3(bytes calldata flashLoanParams, bytes memory payload) internal {
    address pool = flashLoanParams.decodeAddress(0);
    uint256 amount0 = flashLoanParams.decodeUint256(1);
    uint256 amount1 = flashLoanParams.decodeUint256(2);

    bytes memory callbackData = abi.encode(amount0, amount1, payload);
    IUniswapV3Pool(pool).flash(address(this), amount0, amount1, callbackData);
  }

  function _handleUniswapV4(bytes calldata flashLoanParams, bytes memory payload) internal {
    address poolManager = flashLoanParams.decodeAddress(0);
    address[] calldata tokens = flashLoanParams.decodeAddressArray(1);
    uint256[] calldata amounts = flashLoanParams.decodeUint256Array(2);

    bytes memory callbackData = abi.encode(tokens, amounts, payload);
    IPoolManager(poolManager).unlock(callbackData);
  }

  function _handlePancakeInfinity(bytes calldata flashLoanParams, bytes memory payload) internal {
    address vault = flashLoanParams.decodeAddress(0);
    address[] calldata tokens = flashLoanParams.decodeAddressArray(1);
    uint256[] calldata amounts = flashLoanParams.decodeUint256Array(2);

    bytes memory callbackData = abi.encode(tokens, amounts, payload);
    IPancakeInfinityVault(vault).lock(callbackData);
  }

  function _handleEuler(bytes calldata flashLoanParams, bytes memory payload) internal {
    address vault = flashLoanParams.decodeAddress(0);
    uint256 amount = flashLoanParams.decodeUint256(1);

    bytes memory callbackData = abi.encode(amount, payload);
    IEVault(vault).flashLoan(amount, callbackData);
  }

  /// @dev Aave V3 flash loan callback. The pool pulls the amounts owed after the callback returns.
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata fees,
    address, // initiator
    bytes calldata callbackData
  ) external onlyFlashLoanCallback returns (bool) {
    bytes calldata payload = callbackData.decodeBytes(0);

    _onLoan(assets, _computePayAmounts(amounts, fees), payload);

    return true;
  }

  /// @dev ERC3156 flash loan callback. The lender pulls the amount owed after the callback returns.
  function onFlashLoan(
    address, // initiator
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata callbackData
  ) external onlyFlashLoanCallback returns (bytes32) {
    bytes calldata payload = callbackData.decodeBytes(0);

    address[] memory tokens = new address[](1);
    tokens[0] = token;
    uint256[] memory payAmounts = new uint256[](1);
    payAmounts[0] = amount + fee;

    _onLoan(tokens, payAmounts, payload);

    return keccak256('ERC3156FlashBorrower.onFlashLoan');
  }

  /// @dev Morpho Blue flash loan callback. The lender pulls the amount owed after the callback
  /// returns.
  function onMorphoFlashLoan(uint256 amount, bytes calldata callbackData)
    external
    onlyFlashLoanCallback
  {
    _onSingleTokenLoan(amount, callbackData);
  }

  /// @dev Lista Dao flash loan callback. The lender pulls the amount owed after the callback
  /// returns.
  function onMoolahFlashLoan(uint256 amount, bytes calldata callbackData)
    external
    onlyFlashLoanCallback
  {
    _onSingleTokenLoan(amount, callbackData);
  }

  /// @dev Uniswap V3 flash loan callback
  function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata callbackData)
    external
    onlyFlashLoanCallback
  {
    uint256 amount0 = callbackData.decodeUint256(0);
    uint256 amount1 = callbackData.decodeUint256(1);
    bytes calldata payload = callbackData.decodeBytes(2);

    address[] memory tokens;
    uint256[] memory payAmounts;

    if (amount0 == 0 || amount1 == 0) {
      tokens = new address[](1);
      payAmounts = new uint256[](1);

      if (amount0 != 0) {
        tokens[0] = IUniswapV3Pool(msg.sender).token0();
        payAmounts[0] = amount0 + fee0;
      } else {
        tokens[0] = IUniswapV3Pool(msg.sender).token1();
        payAmounts[0] = amount1 + fee1;
      }
    } else {
      tokens = new address[](2);
      payAmounts = new uint256[](2);

      tokens[0] = IUniswapV3Pool(msg.sender).token0();
      payAmounts[0] = amount0 + fee0;

      tokens[1] = IUniswapV3Pool(msg.sender).token1();
      payAmounts[1] = amount1 + fee1;
    }

    _onLoan(tokens, payAmounts, payload);

    _transferTokens(tokens, payAmounts, msg.sender);
  }

  /// @dev Uniswap V4 unlock callback
  function unlockCallback(bytes calldata callbackData)
    external
    onlyFlashLoanCallback
    returns (bytes memory)
  {
    address[] calldata tokens = callbackData.decodeAddressArray(0);
    uint256[] calldata amounts = callbackData.decodeUint256Array(1);
    bytes calldata payload = callbackData.decodeBytes(2);

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].take(IPoolManager(msg.sender), address(this), amounts[i], false);
    }

    _onLoan(tokens, amounts, payload);

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].settle(IPoolManager(msg.sender), address(this), amounts[i], false);
    }

    return '';
  }

  /// @dev Pancake Infinity lock acquired callback
  function lockAcquired(bytes calldata callbackData)
    external
    onlyFlashLoanCallback
    returns (bytes memory)
  {
    address[] calldata tokens = callbackData.decodeAddressArray(0);
    uint256[] calldata amounts = callbackData.decodeUint256Array(1);
    bytes calldata payload = callbackData.decodeBytes(2);

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].take(IPancakeInfinityVault(msg.sender), address(this), amounts[i], false);
    }

    _onLoan(tokens, amounts, payload);

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].settle(IPancakeInfinityVault(msg.sender), address(this), amounts[i], false);
    }

    return '';
  }

  /// @dev Euler flash loan callback. The amount is transferred to the lender after the target runs.
  function onFlashLoan(bytes calldata callbackData) external onlyFlashLoanCallback {
    uint256 amount = callbackData.decodeUint256(0);
    bytes calldata payload = callbackData.decodeBytes(1);

    address[] memory tokens = new address[](1);
    tokens[0] = IEVault(msg.sender).asset();
    uint256[] memory payAmounts = new uint256[](1);
    payAmounts[0] = amount;

    _onLoan(tokens, payAmounts, payload);

    tokens[0].safeTransfer(msg.sender, amount);
  }

  /// @dev Shared body of the Morpho Blue and Lista Dao callbacks, which owe the loaned amount
  function _onSingleTokenLoan(uint256 amount, bytes calldata callbackData) internal {
    address token = callbackData.decodeAddress(0);
    bytes calldata payload = callbackData.decodeBytes(1);

    address[] memory tokens = new address[](1);
    tokens[0] = token;
    uint256[] memory payAmounts = new uint256[](1);
    payAmounts[0] = amount;

    _onLoan(tokens, payAmounts, payload);
  }

  /// @dev Delegatecalls the target of the payload with the loaned tokens and the amounts owed
  function _onLoan(address[] memory tokens, uint256[] memory owedAmounts, bytes calldata payload)
    internal
  {
    address target = payload.decodeAddress(0);
    bytes calldata targetOwnerData = payload.decodeBytes(1);
    bytes calldata targetSolverData = payload.decodeBytes(2);

    bytes memory callData = abi.encodeCall(
      IFlashLoanReceiver.receiveFlashLoan, (tokens, owedAmounts, targetOwnerData, targetSolverData)
    );
    target.functionDelegateCall(callData);
  }

  function _transferTokens(address[] memory tokens, uint256[] memory amounts, address recipient)
    internal
  {
    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].safeTransfer(recipient, amounts[i]);
    }
  }

  function _computePayAmounts(uint256[] calldata amounts, uint256[] calldata fees)
    internal
    pure
    returns (uint256[] memory payAmounts)
  {
    payAmounts = new uint256[](amounts.length);
    for (uint256 i = 0; i < amounts.length; i++) {
      payAmounts[i] = amounts[i] + fees[i];
    }
  }

  receive() external payable {}
}
