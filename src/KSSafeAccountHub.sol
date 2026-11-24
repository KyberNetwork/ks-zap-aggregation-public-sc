// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {ERC721Permit} from './base/ERC721Permit.sol';
import {SafeModulePermission} from './base/SafeModulePermission.sol';
import {IKSSafeAccountHub} from './interfaces/IKSSafeAccountHub.sol';

import {ISettlementContext} from 'ks-allowance-hub/src/interfaces/base/ISettlementContext.sol';
import {CalldataDecoder} from 'ks-common-sc/src/libraries/calldata/CalldataDecoder.sol';

import {ContractCall} from './types/ContractCall.sol';
import {ISafe} from './vendors/safe-smart-account/ISafe.sol';
import {ISafeProxyFactory} from './vendors/safe-smart-account/ISafeProxyFactory.sol';

import {ERC721Holder} from 'openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol';
import {
  ReentrancyGuardTransient
} from 'openzeppelin-contracts/contracts/utils/ReentrancyGuardTransient.sol';
import {TransientSlot} from 'openzeppelin-contracts/contracts/utils/TransientSlot.sol';

/// @title KSSafeAccountHub
/// @notice Creates Safe Accounts owned through an ERC721 token. While it holds the token of a Safe
/// Account, the leverage adapter can run module transactions on that Safe Account and then
/// transfer the token.
/// @dev While an order of the allowance hub is being settled, the token can only be transferred to
/// or from this contract.
contract KSSafeAccountHub is
  IKSSafeAccountHub,
  ERC721Permit,
  SafeModulePermission,
  ERC721Holder,
  ReentrancyGuardTransient
{
  using CalldataDecoder for bytes;
  using TransientSlot for *;

  /// @dev Base of the transient slots that mark the Safe Accounts executed in the transaction
  bytes32 private constant EXECUTED_SLOT = bytes32(erc7201('ks.safe-account-hub.executed'));

  ISafeProxyFactory public immutable SAFE_PROXY_FACTORY;

  address public immutable SAFE_SINGLETON;

  address public constant SENTINEL_OWNERS = address(0x1);

  /// @inheritdoc IKSSafeAccountHub
  address public immutable ALLOWANCE_HUB;

  /// @inheritdoc IKSSafeAccountHub
  address public immutable LEVERAGE_ADAPTER;

  /// @inheritdoc IKSSafeAccountHub
  uint256 public nextTokenId = 1;

  /// @inheritdoc IKSSafeAccountHub
  mapping(address safe => uint256 tokenId) public safeToTokenId;

  /// @inheritdoc IKSSafeAccountHub
  mapping(uint256 tokenId => address safe) public tokenIdToSafe;

  constructor(
    address _allowanceHub,
    address _leverageAdapter,
    address _safeProxyFactory,
    /// The deployer supplies the Safe factory and singleton addresses.
    // forge-lint: disable-next-line(missing-zero-check)
    address _safeSingleton,
    string memory name,
    string memory symbol
  ) ERC721Permit(name, symbol) {
    ALLOWANCE_HUB = _allowanceHub;
    LEVERAGE_ADAPTER = _leverageAdapter;
    SAFE_PROXY_FACTORY = ISafeProxyFactory(_safeProxyFactory);
    SAFE_SINGLETON = _safeSingleton;
  }

  /// @inheritdoc IKSSafeAccountHub
  function createSafe(address owner, uint256 saltNonce) external returns (address safe) {
    /// @dev Ownership is transferred to the owner after setup
    address[] memory owners = new address[](1);
    owners[0] = address(this);

    bytes memory initializer = abi.encodeCall(
      ISafe.setup, (owners, 1, address(0), '', address(0), address(0), 0, payable(address(0)))
    );

    safe = ISafeProxyFactory(SAFE_PROXY_FACTORY)
      .createProxyWithNonce(SAFE_SINGLETON, initializer, saltNonce);

    _execTx(safe, abi.encodeCall(ISafe.enableModule, (address(this))));
    _execTx(safe, abi.encodeCall(ISafe.swapOwner, (SENTINEL_OWNERS, address(this), owner)));

    uint256 tokenId = nextTokenId++;
    /// The owner is the account that created the Safe, and a receiver hook is not required.
    // forge-lint: disable-next-line(unsafe-oz-erc721-mint)
    _mint(owner, tokenId);
    safeToTokenId[safe] = tokenId;
    tokenIdToSafe[tokenId] = safe;

    emit CreateSafe(safe, owner, tokenId);
  }

  /// @inheritdoc IKSSafeAccountHub
  function execute(
    address safe,
    address[] calldata modules,
    ContractCall[] calldata calls,
    address owner
  ) external override nonReentrant returns (bytes[] memory returnData) {
    require(msg.sender == LEVERAGE_ADAPTER, UnauthorizedCaller(msg.sender));

    bytes32 executedSlot = _executedSlot(safe);
    require(!executedSlot.asBoolean().tload(), SafeAlreadyExecuted(safe));
    executedSlot.asBoolean().tstore(true);

    uint256 tokenId = safeToTokenId[safe];
    require(ownerOf(tokenId) == address(this), UnauthorizedSafe());

    for (uint256 i = 0; i < modules.length; i++) {
      require(
        _execTxFromModule(safe, abi.encodeCall(this.enableModule, (modules[i]))),
        EnableModuleFailed()
      );
    }

    returnData = new bytes[](calls.length);
    for (uint256 i = 0; i < calls.length; i++) {
      returnData[i] = _execTxFromModuleReturnData(safe, calls[i]);
    }

    for (uint256 i = 0; i < modules.length; i++) {
      require(
        _execTxFromModule(safe, abi.encodeCall(this.disableModule, (modules[i]))),
        DisableModuleFailed()
      );
    }

    _transfer(address(this), owner, tokenId);
  }

  /// @dev Refuses the transfers of the token other than to or from this contract while an order of
  /// the allowance hub is being settled. A mint is not restricted.
  function _update(address to, uint256 tokenId, address auth)
    internal
    override
    returns (address from)
  {
    from = _ownerOf(tokenId);
    if (from != address(0) && ISettlementContext(ALLOWANCE_HUB).msgSender() != address(0)) {
      bool involvesHub = to == address(this) || from == address(this);
      require(involvesHub, TransferDuringSettlement(from, to));
    }
    return super._update(to, tokenId, auth);
  }

  /// @dev Returns the transient slot that marks `safe` as executed
  function _executedSlot(address safe) internal pure returns (bytes32) {
    return keccak256(abi.encode(EXECUTED_SLOT, safe));
  }

  function _execTx(address safe, bytes memory data) internal {
    bytes memory signatures = bytes.concat(abi.encode(address(this), 0), bytes1(0x01));

    ISafe(safe)
      .execTransaction(
        safe, 0, data, ISafe.Operation.Call, 0, 0, 0, address(0), payable(address(0)), signatures
      );
  }

  function _execTxFromModule(address safe, bytes memory data) internal returns (bool success) {
    success =
    /// The Safe is called once per module or call entry by design.
    /// The token stays owned by this contract until the final transfer of execute.
    // forge-lint: disable-next-line(reentrancy-no-eth)
    ISafe(safe).execTransactionFromModule(address(this), 0, data, ISafe.Operation.DelegateCall);
  }

  function _execTxFromModuleReturnData(address safe, ContractCall calldata contractCall)
    internal
    returns (bytes memory returnData)
  {
    bool success;
    /// The Safe is called once per module or call entry by design.
    /// The token stays owned by this contract until the final transfer of execute.
    // forge-lint: disable-next-item(reentrancy-no-eth)
    (success, returnData) = ISafe(safe)
      .execTransactionFromModuleReturnData(
        contractCall.target,
        0,
        contractCall.data,
        contractCall.isDelegateCall ? ISafe.Operation.DelegateCall : ISafe.Operation.Call
      );

    if (!success) {
      revert SafeModuleExecutionFailed(returnData);
    }
  }
}
