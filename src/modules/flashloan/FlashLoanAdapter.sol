// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ImmutableState} from '../../base/ImmutableState.sol';
import {IFlashLoanAdapter} from '../../interfaces/modules/flashloan/IFlashLoanAdapter.sol';
import {IFlashLoanReceiver} from '../../interfaces/modules/flashloan/IFlashLoanReceiver.sol';

import {IPool} from '../../vendors/aave-v3/IPool.sol';
import {IVault as IBalancerV2Vault} from '../../vendors/balancer-v2/IVault.sol';
import {IVault as IBalancerV3Vault} from '../../vendors/balancer-v3/IVault.sol';
import {IEVault} from '../../vendors/euler-v2/IEVault.sol';
import {IMorpho} from '../../vendors/morpho/IMorpho.sol';
import {ISafe} from '../../vendors/safe-smart-account/ISafe.sol';
import {IUniswapV3Pool} from '../../vendors/uniswap-v3/IUniswapV3Pool.sol';

import {MASK_160_BITS, MASK_8_BITS} from '../../libraries/BitMask.sol';
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

import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';
import {TokenHelper} from 'ks-common-sc/src/libraries/token/TokenHelper.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/interfaces/IERC20.sol';
import {
  IERC3156FlashBorrower,
  IERC3156FlashLender
} from 'openzeppelin-contracts/contracts/interfaces/IERC3156FlashLender.sol';

contract FlashLoanAdapter is IFlashLoanAdapter, ImmutableState {
  using CalldataDecoder for bytes;
  using TokenHelper for address;
  using CommonLibrary for *;
  using PancakeInfinityCurrencySettler for address;
  using UniswapV4CurrencySettler for address;

  constructor(address _WETH) ImmutableState(_WETH) {}

  function flashLoan(uint256 flashLoanContext, bytes calldata flashLoanParams, bytes calldata data)
    external
    payable
  {
    (FlashLoanSource source, ReceiverType receiverType) = _unpackFlashLoanContext(flashLoanContext);

    if (source == FlashLoanSource.AAVE_V3) {
      _handleAaveV3(receiverType, flashLoanParams, data);
    } else if (source == FlashLoanSource.BALANCER_V2) {
      _handleBalancerV2(receiverType, flashLoanParams, data);
    } else if (source == FlashLoanSource.BALANCER_V3) {
      _handleBalancerV3(receiverType, flashLoanParams, data);
    } else if (source == FlashLoanSource.ERC3156) {
      _handleERC3156(receiverType, flashLoanParams, data);
    } else if (source == FlashLoanSource.MORPHO_BLUE) {
      _handleMorphoBlue(receiverType, flashLoanParams, data);
    } else if (source == FlashLoanSource.UNISWAP_V3) {
      _handleUniswapV3(receiverType, flashLoanParams, data);
    } else if (source == FlashLoanSource.UNISWAP_V4) {
      _handleUniswapV4(receiverType, flashLoanParams, data);
    } else if (source == FlashLoanSource.PANCAKE_INFINITY) {
      _handlePancakeInfinity(receiverType, flashLoanParams, data);
    } else if (source == FlashLoanSource.EULER_V2) {
      _handleEuler(receiverType, flashLoanParams, data);
    }
  }

  function _handleAaveV3(
    ReceiverType receiverType,
    bytes calldata flashLoanParams,
    bytes calldata data
  ) internal {
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

    IPool(pool)
      .flashLoan(
        address(this),
        tokens,
        amounts,
        new uint256[](tokens.length),
        address(0),
        abi.encode(_packReceiveInfo(receiverType, msg.sender), data),
        0
      );
  }

  function _handleBalancerV2(
    ReceiverType receiverType,
    bytes calldata flashLoanParams,
    bytes calldata data
  ) internal {
    address vault = flashLoanParams.decodeAddress(0);
    address[] calldata tokens = flashLoanParams.decodeAddressArray(1);
    uint256[] calldata amounts = flashLoanParams.decodeUint256Array(2);

    IBalancerV2Vault(vault)
      .flashLoan(
        address(this), tokens, amounts, abi.encode(_packReceiveInfo(receiverType, msg.sender), data)
      );
  }

  function _handleBalancerV3(
    ReceiverType receiverType,
    bytes calldata flashLoanParams,
    bytes calldata data
  ) internal {
    address vault = flashLoanParams.decodeAddress(0);
    address[] calldata tokens = flashLoanParams.decodeAddressArray(1);
    uint256[] calldata amounts = flashLoanParams.decodeUint256Array(2);

    IBalancerV3Vault(vault)
      .unlock(
        abi.encodeCall(
          this.balancerV3Callback,
          (_packReceiveInfo(receiverType, msg.sender), tokens, amounts, data)
        )
      );
  }

  function _handleERC3156(
    ReceiverType receiverType,
    bytes calldata flashLoanParams,
    bytes calldata data
  ) internal {
    address lender = flashLoanParams.decodeAddress(0);
    BoolAddress tokenInfo = BoolAddress.wrap(flashLoanParams.decodeUint256(1));
    uint256 amount = flashLoanParams.decodeUint256(2);

    address token = tokenInfo.addressValue();
    if (tokenInfo.boolValue()) {
      token.forceApproveInf(lender);
    }

    IERC3156FlashLender(lender)
      .flashLoan(
        IERC3156FlashBorrower(address(this)),
        token,
        amount,
        abi.encode(_packReceiveInfo(receiverType, msg.sender), data)
      );
  }

  function _handleMorphoBlue(
    ReceiverType receiverType,
    bytes calldata flashLoanParams,
    bytes calldata data
  ) internal {
    address morpho = flashLoanParams.decodeAddress(0);
    BoolAddress tokenInfo = BoolAddress.wrap(flashLoanParams.decodeUint256(1));
    uint256 amount = flashLoanParams.decodeUint256(2);

    address token = tokenInfo.addressValue();
    if (tokenInfo.boolValue()) {
      token.forceApproveInf(morpho);
    }

    IMorpho(morpho)
      .flashLoan(token, amount, abi.encode(_packReceiveInfo(receiverType, msg.sender), token, data));
  }

  function _handleUniswapV3(
    ReceiverType receiverType,
    bytes calldata flashLoanParams,
    bytes calldata data
  ) internal {
    address pool = flashLoanParams.decodeAddress(0);
    uint256 amount0 = flashLoanParams.decodeUint256(1);
    uint256 amount1 = flashLoanParams.decodeUint256(2);

    IUniswapV3Pool(pool)
      .flash(
        address(this),
        amount0,
        amount1,
        abi.encode(_packReceiveInfo(receiverType, msg.sender), amount0, amount1, data)
      );
  }

  function _handleUniswapV4(
    ReceiverType receiverType,
    bytes calldata flashLoanParams,
    bytes calldata data
  ) internal {
    address poolManager = flashLoanParams.decodeAddress(0);
    address[] calldata tokens = flashLoanParams.decodeAddressArray(1);
    uint256[] calldata amounts = flashLoanParams.decodeUint256Array(2);

    IPoolManager(poolManager)
      .unlock(abi.encode(_packReceiveInfo(receiverType, msg.sender), tokens, amounts, data));
  }

  function _handlePancakeInfinity(
    ReceiverType receiverType,
    bytes calldata flashLoanParams,
    bytes calldata data
  ) internal {
    address vault = flashLoanParams.decodeAddress(0);
    address[] calldata tokens = flashLoanParams.decodeAddressArray(1);
    uint256[] calldata amounts = flashLoanParams.decodeUint256Array(2);

    IPancakeInfinityVault(vault)
      .lock(abi.encode(_packReceiveInfo(receiverType, msg.sender), tokens, amounts, data));
  }

  function _handleEuler(
    ReceiverType receiverType,
    bytes calldata flashLoanParams,
    bytes calldata data
  ) internal {
    address vault = flashLoanParams.decodeAddress(0);
    uint256 amount = flashLoanParams.decodeUint256(1);

    IEVault(vault)
      .flashLoan(amount, abi.encode(_packReceiveInfo(receiverType, msg.sender), amount, data));
  }

  /// @dev Aave V3 flash loan callback
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata fees,
    address, // initiator
    bytes calldata callbackData
  ) external returns (bool) {
    (ReceiverType receiverType, address receiver) =
      _unpackReceiverInfo(callbackData.decodeUint256(0));
    bytes calldata data = callbackData.decodeBytes(1);

    for (uint256 i = 0; i < assets.length; i++) {
      assets[i].safeTransfer(receiver, amounts[i]);
    }

    uint256[] memory payAmounts = _computePayAmounts(amounts, fees);
    _receiveFlashLoan(receiverType, receiver, assets, payAmounts, data);

    return true;
  }

  /// @dev Balancer V2 flash loan callback
  function receiveFlashLoan(
    address[] calldata tokens,
    uint256[] calldata amounts,
    uint256[] calldata feeAmounts,
    bytes calldata callbackData
  ) external {
    (ReceiverType receiverType, address receiver) =
      _unpackReceiverInfo(callbackData.decodeUint256(0));
    bytes calldata data = callbackData.decodeBytes(1);

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].safeTransfer(receiver, amounts[i]);
    }

    uint256[] memory payAmounts = _computePayAmounts(amounts, feeAmounts);
    _receiveFlashLoan(receiverType, receiver, tokens, payAmounts, data);

    _transferTokens(tokens, payAmounts, msg.sender);
  }

  /// @dev Balancer V3 flash loan callback
  function balancerV3Callback(
    uint256 receiverInfo,
    address[] calldata tokens,
    uint256[] calldata amounts,
    bytes calldata data
  ) external {
    (ReceiverType receiverType, address receiver) = _unpackReceiverInfo(receiverInfo);
    for (uint256 i = 0; i < tokens.length; i++) {
      IBalancerV3Vault(msg.sender).sendTo(tokens[i], receiver, amounts[i]);
    }

    _receiveFlashLoan(receiverType, receiver, tokens, amounts, data);

    _transferTokens(tokens, amounts, msg.sender);
    for (uint256 i = 0; i < tokens.length; i++) {
      IBalancerV3Vault(msg.sender).settle(tokens[i], amounts[i]);
    }
  }

  /// @dev ERC3156 flash loan callback
  function onFlashLoan(
    address, // initiator
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata callbackData
  ) external returns (bytes32) {
    (ReceiverType receiverType, address receiver) =
      _unpackReceiverInfo(callbackData.decodeUint256(0));
    bytes calldata data = callbackData.decodeBytes(1);

    token.safeTransfer(receiver, amount);

    address[] memory tokens = new address[](1);
    tokens[0] = token;
    uint256[] memory payAmounts = new uint256[](1);
    payAmounts[0] = amount + fee;

    _receiveFlashLoan(receiverType, receiver, tokens, payAmounts, data);

    return keccak256('ERC3156FlashBorrower.onFlashLoan');
  }

  /// @dev Morpho Blue flash loan callback
  function onMorphoFlashLoan(uint256 amount, bytes calldata callbackData) external {
    (ReceiverType receiverType, address receiver) =
      _unpackReceiverInfo(callbackData.decodeUint256(0));
    address token = callbackData.decodeAddress(1);
    bytes calldata data = callbackData.decodeBytes(2);

    token.safeTransfer(receiver, amount);

    address[] memory tokens = new address[](1);
    tokens[0] = token;
    uint256[] memory payAmounts = new uint256[](1);
    payAmounts[0] = amount;

    _receiveFlashLoan(receiverType, receiver, tokens, payAmounts, data);
  }

  /// @dev Lista Dao flash loan callback
  function onMoolahFlashLoan(uint256 amount, bytes calldata callbackData) external {
    (ReceiverType receiverType, address receiver) =
      _unpackReceiverInfo(callbackData.decodeUint256(0));
    address token = callbackData.decodeAddress(1);
    bytes calldata data = callbackData.decodeBytes(2);

    token.safeTransfer(receiver, amount);

    address[] memory tokens = new address[](1);
    tokens[0] = token;
    uint256[] memory payAmounts = new uint256[](1);
    payAmounts[0] = amount;

    _receiveFlashLoan(receiverType, receiver, tokens, payAmounts, data);
  }

  /// @dev Uniswap V3 flash loan callback
  function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata callbackData)
    external
  {
    (ReceiverType receiverType, address receiver) =
      _unpackReceiverInfo(callbackData.decodeUint256(0));
    uint256 amount0 = callbackData.decodeUint256(1);
    uint256 amount1 = callbackData.decodeUint256(2);
    bytes calldata data = callbackData.decodeBytes(3);

    address[] memory tokens;
    uint256[] memory payAmounts;

    if (amount0 == 0 || amount1 == 0) {
      tokens = new address[](1);
      payAmounts = new uint256[](1);

      if (amount0 != 0) {
        tokens[0] = IUniswapV3Pool(msg.sender).token0();
        payAmounts[0] = amount0 + fee0;
        tokens[0].safeTransfer(receiver, amount0);
      } else {
        tokens[0] = IUniswapV3Pool(msg.sender).token1();
        payAmounts[0] = amount1 + fee1;
        tokens[0].safeTransfer(receiver, amount1);
      }
    } else {
      tokens = new address[](2);
      payAmounts = new uint256[](2);

      tokens[0] = IUniswapV3Pool(msg.sender).token0();
      payAmounts[0] = amount0 + fee0;
      tokens[0].safeTransfer(receiver, amount0);

      tokens[1] = IUniswapV3Pool(msg.sender).token1();
      payAmounts[1] = amount1 + fee1;
      tokens[1].safeTransfer(receiver, amount1);
    }

    _receiveFlashLoan(receiverType, receiver, tokens, payAmounts, data);

    _transferTokens(tokens, payAmounts, msg.sender);
  }

  /// @dev Uniswap V4 unlock callback
  function unlockCallback(bytes calldata callbackData) external returns (bytes memory) {
    (ReceiverType receiverType, address receiver) =
      _unpackReceiverInfo(callbackData.decodeUint256(0));
    address[] calldata tokens = callbackData.decodeAddressArray(1);
    uint256[] calldata amounts = callbackData.decodeUint256Array(2);
    bytes calldata data = callbackData.decodeBytes(3);

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].take(IPoolManager(msg.sender), receiver, amounts[i], false);
    }

    _receiveFlashLoan(receiverType, receiver, tokens, amounts, data);

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].settle(IPoolManager(msg.sender), address(this), amounts[i], false);
    }
  }

  /// @dev Pancake Infinity lock acquired callback
  function lockAcquired(bytes calldata callbackData) external returns (bytes memory) {
    (ReceiverType receiverType, address receiver) =
      _unpackReceiverInfo(callbackData.decodeUint256(0));
    address[] calldata tokens = callbackData.decodeAddressArray(1);
    uint256[] calldata amounts = callbackData.decodeUint256Array(2);
    bytes calldata data = callbackData.decodeBytes(3);

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].take(IPancakeInfinityVault(msg.sender), receiver, amounts[i], false);
    }

    _receiveFlashLoan(receiverType, receiver, tokens, amounts, data);

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].settle(IPancakeInfinityVault(msg.sender), address(this), amounts[i], false);
    }
  }

  /// @dev Euler flash loan callback
  function onFlashLoan(bytes calldata callbackData) external {
    (ReceiverType receiverType, address receiver) =
      _unpackReceiverInfo(callbackData.decodeUint256(0));
    uint256 amount = callbackData.decodeUint256(1);
    bytes calldata data = callbackData.decodeBytes(2);

    address[] memory tokens = new address[](1);
    tokens[0] = IEVault(msg.sender).asset();
    uint256[] memory payAmounts = new uint256[](1);
    payAmounts[0] = amount;

    tokens[0].safeTransfer(receiver, amount);

    _receiveFlashLoan(receiverType, receiver, tokens, payAmounts, data);

    tokens[0].safeTransfer(msg.sender, amount);
  }

  function _receiveFlashLoan(
    ReceiverType receiverType,
    address receiver,
    address[] memory tokens,
    uint256[] memory amounts,
    bytes calldata data
  ) internal virtual {
    if (receiverType == ReceiverType.SAFE_ACCOUNT) {
      address executor = data.decodeAddress(0);
      bytes calldata executorData = data.decodeBytes(1);

      (bool success, bytes memory returnData) = ISafe(receiver)
        .execTransactionFromModuleReturnData(
          executor,
          0,
          abi.encodeCall(IFlashLoanReceiver.receiveFlashLoan, (tokens, amounts, executorData)),
          ISafe.Operation.DelegateCall
        );

      if (!success) {
        revert SafeModuleExecutionFailed(returnData);
      }
    } else {
      IFlashLoanReceiver(receiver).receiveFlashLoan(tokens, amounts, data);
    }
  }

  function _unpackFlashLoanContext(uint256 flashLoanContext)
    internal
    pure
    returns (FlashLoanSource source, ReceiverType receiverType)
  {
    assembly ('memory-safe') {
      source := shr(8, flashLoanContext)
      receiverType := and(flashLoanContext, MASK_8_BITS)
    }
  }

  function _packReceiveInfo(ReceiverType receiverType, address receiver)
    internal
    pure
    returns (uint256 receiverInfo)
  {
    assembly ('memory-safe') {
      receiverInfo := or(shl(160, receiverType), receiver)
    }
  }

  function _unpackReceiverInfo(uint256 receiverInfo)
    internal
    pure
    returns (ReceiverType receiverType, address receiver)
  {
    assembly ('memory-safe') {
      receiverType := shr(160, receiverInfo)
      receiver := and(receiverInfo, MASK_160_BITS)
    }
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
