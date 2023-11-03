// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";

import { IMessageExecutor } from "../interfaces/IMessageExecutor.sol";
import {
  IMessageDispatcher,
  ISingleMessageDispatcher,
  IBatchMessageDispatcher,
  IMessageDispatcherArbitrum
} from "../interfaces/extensions/IMessageDispatcherArbitrum.sol";

import { MessageLib } from "../libraries/MessageLib.sol";

/**
 * @title MessageDispatcherArbitrum contract
 * @notice The MessageDispatcherArbitrum contract allows a user or contract to send messages from Ethereum to Arbitrum.
 *         It lives on the Ethereum chain and communicates with the `MessageExecutorArbitrum` contract on the Arbitrum chain.
 */
contract MessageDispatcherArbitrum is IMessageDispatcherArbitrum {
  /* ============ Variables ============ */

  /// @notice Address of the Arbitrum inbox on the Ethereum chain.
  IInbox public immutable inbox;

  /// @notice Address of the executor contract on the Arbitrum chain.
  IMessageExecutor internal executor;

  /// @notice Nonce used to compute unique `messageId`s.
  uint256 internal nonce;

  /// @notice ID of the chain receiving the dispatched messages. i.e.: 42161 for Mainnet, 421613 for Goerli.
  uint256 internal immutable toChainId;

  /**
   * @notice Hash of transactions that were dispatched in `dispatchMessage` or `dispatchMessageBatch`.
   *         txHash => boolean
   * @dev Ensure that messages passed to `processMessage` and `processMessageBatch` have been dispatched first.
   */
  mapping(bytes32 => bool) public dispatched;

  /* ============ Constructor ============ */

  /**
   * @notice MessageDispatcher constructor.
   * @param _inbox Address of the Arbitrum inbox on Ethereum
   * @param _toChainId ID of the chain receiving the dispatched messages
   */
  constructor(IInbox _inbox, uint256 _toChainId) {
    require(address(_inbox) != address(0), "Dispatcher/inbox-not-zero-adrs");
    require(_toChainId != 0, "Dispatcher/chainId-not-zero");

    inbox = _inbox;
    toChainId = _toChainId;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc IMessageDispatcher
  function dispatchMessage(
    uint256 _toChainId,
    address _to,
    bytes calldata _data
  ) external returns (bytes32) {
    _checkToChainId(_toChainId);

    bytes32 _messageId = _computeMessageId(msg.sender, _to, _data);

    dispatched[_getMessageTxHash(_messageId, msg.sender, _to, _data)] = true;

    emit MessageDispatched(_messageId, msg.sender, _toChainId, _to, _data);

    return _messageId;
  }

  /// @inheritdoc IBatchMessageDispatcher
  function dispatchMessageBatch(
    uint256 _toChainId,
    MessageLib.Message[] calldata _messages
  ) external returns (bytes32) {
    _checkToChainId(_toChainId);

    bytes32 _messageId = _computeMessageBatchId(msg.sender, _messages);

    dispatched[_getMessageBatchTxHash(_messageId, msg.sender, _messages)] = true;

    emit MessageBatchDispatched(_messageId, msg.sender, _toChainId, _messages);

    return _messageId;
  }

  /**
   * @inheritdoc IMessageDispatcherArbitrum
   * @dev The transaction hash must match the one stored in the `dispatched` mapping.
   * @dev `_refundAddress` is passed as `_callValueRefundAddress`, this address can cancel the retryable ticket.
   * @dev We store `_message` in memory to avoid a stack too deep error.
   */
  function processMessage(
    bytes32 _messageId,
    address _from,
    address _to,
    bytes calldata _data,
    address _refundAddress,
    uint256 _gasLimit,
    uint256 _maxSubmissionCost,
    uint256 _gasPriceBid
  ) external payable returns (uint256) {
    require(
      dispatched[_getMessageTxHash(_messageId, _from, _to, _data)],
      "Dispatcher/msg-not-dispatched"
    );

    address _executorAddress = address(executor);
    _checkProcessParams(_executorAddress, _refundAddress);

    bytes memory _message = MessageLib.encodeMessage(_to, _data, _messageId, block.chainid, _from);

    uint256 _ticketId = _createRetryableTicket(
      _executorAddress,
      _maxSubmissionCost,
      _refundAddress,
      _refundAddress,
      _gasLimit,
      _gasPriceBid,
      _message
    );

    emit MessageProcessed(_messageId, msg.sender, _ticketId);

    return _ticketId;
  }

  /**
   * @inheritdoc IMessageDispatcherArbitrum
   * @dev The transaction hash must match the one stored in the `dispatched` mapping.
   * @dev `_refundAddress` is passed as `_callValueRefundAddress`, this address can cancel the retryable ticket.
   * @dev We store `_messageBatch` in memory to avoid a stack too deep error.
   */
  function processMessageBatch(
    bytes32 _messageId,
    MessageLib.Message[] calldata _messages,
    address _from,
    address _refundAddress,
    uint256 _gasLimit,
    uint256 _maxSubmissionCost,
    uint256 _gasPriceBid
  ) external payable returns (uint256) {
    require(
      dispatched[_getMessageBatchTxHash(_messageId, _from, _messages)],
      "Dispatcher/msges-not-dispatched"
    );

    address _executorAddress = address(executor);
    _checkProcessParams(_executorAddress, _refundAddress);

    bytes memory _messageBatch = MessageLib.encodeMessageBatch(
      _messages,
      _messageId,
      block.chainid,
      _from
    );

    uint256 _ticketId = _createRetryableTicket(
      _executorAddress,
      _maxSubmissionCost,
      _refundAddress,
      _refundAddress,
      _gasLimit,
      _gasPriceBid,
      _messageBatch
    );

    emit MessageBatchProcessed(_messageId, msg.sender, _ticketId);

    return _ticketId;
  }

  /**
   * @inheritdoc IMessageDispatcherArbitrum
   * @dev `_refundAddress` is passed as `_callValueRefundAddress`, this address can cancel the retryable ticket.
   * @dev We store `_message` in memory to avoid a stack too deep error.
   */
  function dispatchAndProcessMessage(
    uint256 _toChainId,
    address _to,
    bytes calldata _data,
    address _refundAddress,
    uint256 _gasLimit,
    uint256 _maxSubmissionCost,
    uint256 _gasPriceBid
  ) external payable returns (bytes32 messageId, uint256 ticketId) {
    address _executorAddress = address(executor);
    _checkProcessParams(_executorAddress, _refundAddress);
    _checkToChainId(_toChainId);

    messageId = _computeMessageId(msg.sender, _to, _data);
    bytes memory _message = MessageLib.encodeMessage(
      _to,
      _data,
      messageId,
      block.chainid,
      msg.sender
    );

    ticketId = _createRetryableTicket(
      _executorAddress,
      _maxSubmissionCost,
      _refundAddress,
      _refundAddress,
      _gasLimit,
      _gasPriceBid,
      _message
    );

    emit MessageDispatched(messageId, msg.sender, _toChainId, _to, _data);
    emit MessageProcessed(messageId, msg.sender, ticketId);
  }

  /**
   * @inheritdoc IMessageDispatcherArbitrum
   * @dev `_refundAddress` is passed as `_callValueRefundAddress`, this address can cancel the retryable ticket.
   * @dev We store `_messageBatch` in memory to avoid a stack too deep error.
   */
  function dispatchAndProcessMessageBatch(
    uint256 _toChainId,
    MessageLib.Message[] calldata _messages,
    address _refundAddress,
    uint256 _gasLimit,
    uint256 _maxSubmissionCost,
    uint256 _gasPriceBid
  ) external payable returns (bytes32 messageId, uint256 ticketId) {
    address _executorAddress = address(executor);
    _checkProcessParams(_executorAddress, _refundAddress);
    _checkToChainId(_toChainId);

    messageId = _computeMessageBatchId(msg.sender, _messages);
    bytes memory _messageBatch = MessageLib.encodeMessageBatch(
      _messages,
      messageId,
      block.chainid,
      msg.sender
    );

    ticketId = _createRetryableTicket(
      _executorAddress,
      _maxSubmissionCost,
      _refundAddress,
      _refundAddress,
      _gasLimit,
      _gasPriceBid,
      _messageBatch
    );

    emit MessageBatchDispatched(messageId, msg.sender, _toChainId, _messages);
    emit MessageBatchProcessed(messageId, msg.sender, ticketId);
  }

  /**
   * @notice Set executor contract address.
   * @dev Will revert if it has already been set.
   * @param _executor Address of the executor contract on the Arbitrum chain
   */
  function setExecutor(IMessageExecutor _executor) external {
    require(address(executor) == address(0), "Dispatcher/executor-already-set");
    executor = _executor;
  }

  /**
   * @notice Get transaction hash for a single message.
   * @dev The transaction hash is used to ensure that only messages that were dispatched are processed.
   * @param _messageId ID uniquely identifying the message that was dispatched
   * @param _from Address who dispatched the message
   * @param _to Address that will receive the message
   * @param _data Data that was dispatched
   * @return bytes32 Transaction hash
   */
  function getMessageTxHash(
    bytes32 _messageId,
    address _from,
    address _to,
    bytes calldata _data
  ) external view returns (bytes32) {
    return _getMessageTxHash(_messageId, _from, _to, _data);
  }

  /**
   * @notice Get transaction hash for a batch of messages.
   * @dev The transaction hash is used to ensure that only messages that were dispatched are processed.
   * @param _messageId ID uniquely identifying the messages that were dispatched
   * @param _from Address who dispatched the messages
   * @param _messages Array of messages that were dispatched
   * @return bytes32 Transaction hash
   */
  function getMessageBatchTxHash(
    bytes32 _messageId,
    address _from,
    MessageLib.Message[] calldata _messages
  ) external view returns (bytes32) {
    return _getMessageBatchTxHash(_messageId, _from, _messages);
  }

  /// @inheritdoc ISingleMessageDispatcher
  function getMessageExecutorAddress(uint256 _toChainId) external view returns (address) {
    _checkToChainId(_toChainId);
    return address(executor);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Get transaction hash for a single message.
   * @dev The transaction hash is used to ensure that only messages that were dispatched are processed.
   * @param _messageId ID uniquely identifying the message that was dispatched
   * @param _from Address who dispatched the message
   * @param _to Address that will receive the message
   * @param _data Data that was dispatched
   * @return bytes32 Transaction hash
   */
  function _getMessageTxHash(
    bytes32 _messageId,
    address _from,
    address _to,
    bytes memory _data
  ) internal view returns (bytes32) {
    return keccak256(abi.encode(address(this), _messageId, _from, _to, _data));
  }

  /**
   * @notice Get transaction hash for a batch of messages.
   * @dev The transaction hash is used to ensure that only messages that were dispatched are processed.
   * @param _messageId ID uniquely identifying the messages that were dispatched
   * @param _from Address who dispatched the messages
   * @param _messages Array of messages that were dispatched
   * @return bytes32 Transaction hash
   */
  function _getMessageBatchTxHash(
    bytes32 _messageId,
    address _from,
    MessageLib.Message[] memory _messages
  ) internal view returns (bytes32) {
    return keccak256(abi.encode(address(this), _messageId, _from, _messages));
  }

  /**
   * @notice Check toChainId to ensure messages can be dispatched to this chain.
   * @dev Will revert if `_toChainId` is not supported.
   * @param _toChainId ID of the chain receiving the message
   */
  function _checkToChainId(uint256 _toChainId) internal view {
    require(_toChainId == toChainId, "Dispatcher/chainId-not-supported");
  }

  /**
   * @notice Check process parameters to ensure messages can be dispatched.
   * @dev Will revert if `executor` is not set.
   * @dev Will revert if `_refund` is address zero.
   * @param _executor Address of the executor contract on the Optimism chain
   * @param _refund Address that will receive the `excessFeeRefund` amount if any
   */
  function _checkProcessParams(address _executor, address _refund) internal pure {
    require(_executor != address(0), "Dispatcher/executor-not-set");
    require(_refund != address(0), "Dispatcher/refund-not-zero-adrs");
  }

  /**
   * @notice Helper to increment nonce.
   * @return uint256 Incremented nonce
   */
  function _incrementNonce() internal returns (uint256) {
    unchecked {
      nonce++;
    }

    return nonce;
  }

  /**
   * @notice Compute message ID.
   * @param _from Address that dispatched the message
   * @param _to Address that will receive the message
   * @param _data Data to dispatch
   */
  function _computeMessageId(
    address _from,
    address _to,
    bytes calldata _data
  ) internal returns (bytes32) {
    return MessageLib.computeMessageId(_incrementNonce(), _from, _to, _data);
  }

  /**
   * @notice Compute message batch ID.
   * @param _from Address that dispatched the batch of messages
   * @param _messages Array of Message to dispatch
   */
  function _computeMessageBatchId(
    address _from,
    MessageLib.Message[] memory _messages
  ) internal returns (bytes32) {
    return MessageLib.computeMessageBatchId(_incrementNonce(), _from, _messages);
  }

  /**
   * @notice Put a message in the L2 inbox that can be reexecuted for some fixed amount of time if it reverts
   * @dev all msg.value will be deposited to `_callValueRefundAddress` on L2
   * @dev `_gasLimit` and `_gasPriceBid` should not be set to 1 as that is used to trigger the RetryableData error
   * @param _to Destination L2 contract address
   * @param _maxSubmissionCost Max gas deducted from user's L2 balance to cover base submission fee
   * @param _excessFeeRefundAddress `_gasLimit` x `_gasPriceBid` - execution cost gets credited here on L2 balance
   * @param _callValueRefundAddress l2Callvalue gets credited here on L2 if retryable txn times out or gets cancelled
   * @param _gasLimit Max gas deducted from user's L2 balance to cover L2 execution. Should not be set to 1 (magic value used to trigger the RetryableData error)
   * @param _gasPriceBid Price bid for L2 execution. Should not be set to 1 (magic value used to trigger the RetryableData error)
   * @param _data ABI encoded data of L2 message
   * @return uint256 Unique message number of the retryable transaction
   */
  function _createRetryableTicket(
    address _to,
    uint256 _maxSubmissionCost,
    address _excessFeeRefundAddress,
    address _callValueRefundAddress,
    uint256 _gasLimit,
    uint256 _gasPriceBid,
    bytes memory _data
  ) internal returns (uint256) {
    return
      inbox.createRetryableTicket{ value: msg.value }(
        _to,
        0, // l2CallValue
        _maxSubmissionCost,
        _excessFeeRefundAddress,
        _callValueRefundAddress,
        _gasLimit,
        _gasPriceBid,
        _data
      );
  }
}
