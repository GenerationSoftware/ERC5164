// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import {
  MessageLib,
  IMessageDispatcher,
  ISingleMessageDispatcher,
  IBatchMessageDispatcher
} from "./IBatchMessageDispatcher.sol";

/**
 * @title MessageDispatcherArbitrum interface
 * @dev IBatchMessageDispatcher interface extended to support Arbitrum two steps message dispatch.
 */
interface IMessageDispatcherArbitrum is IBatchMessageDispatcher {
  /**
   * @notice Emitted once a message has been processed and put in the Arbitrum inbox.
   * @dev Using the `ticketId`, this message can be reexecuted for some fixed amount of time if it reverts.
   * @param messageId ID uniquely identifying the message
   * @param sender Address who processed the message
   * @param ticketId ID of the newly created retryable ticket
   */
  event MessageProcessed(
    bytes32 indexed messageId,
    address indexed sender,
    uint256 indexed ticketId
  );

  /**
   * @notice Emitted once a message has been processed and put in the Arbitrum inbox.
   * @dev Using the `ticketId`, this message can be reexecuted for some fixed amount of time if it reverts.
   * @param messageId ID uniquely identifying the messages
   * @param sender Address who processed the messages
   * @param ticketId ID of the newly created retryable ticket
   */
  event MessageBatchProcessed(
    bytes32 indexed messageId,
    address indexed sender,
    uint256 indexed ticketId
  );

  /**
   * @notice Process message that has been dispatched.
   * @dev Must compute and return the ID of the retryable ticket that was created.
   * @dev Must emit the `MessageProcessed` event when successfully processed.
   * @param messageId ID of the message to process
   * @param from Address who dispatched the `data`
   * @param to Address that will receive the message
   * @param data Data that was dispatched
   * @param refundAddress Address that will receive the `excessFeeRefund` amount if any
   * @param gasLimit Maximum amount of gas required for the `messages` to be executed
   * @param maxSubmissionCost Max gas deducted from user's L2 balance to cover base submission fee
   * @param gasPriceBid Gas price bid for L2 execution
   * @return ID of the retryable ticket that was created
   */
  function processMessage(
    bytes32 messageId,
    address from,
    address to,
    bytes calldata data,
    address refundAddress,
    uint256 gasLimit,
    uint256 maxSubmissionCost,
    uint256 gasPriceBid
  ) external payable returns (uint256);

  /**
   * @notice Process messages that have been dispatched.
   * @dev Must compute and return the ID of the retryable ticket that was created.
   * @dev Must emit the `MessageBatchProcessed` event when successfully processed.
   * @param messageId ID of the messages to process
   * @param messages Array of messages being processed
   * @param from Address who dispatched the `messages`
   * @param refundAddress Address that will receive the `excessFeeRefund` amount if any
   * @param gasLimit Maximum amount of gas required for the `messages` to be executed
   * @param maxSubmissionCost Max gas deducted from user's L2 balance to cover base submission fee
   * @param gasPriceBid Gas price bid for L2 execution
   * @return ticketId ID of the retryable ticket that was created
   */
  function processMessageBatch(
    bytes32 messageId,
    MessageLib.Message[] calldata messages,
    address from,
    address refundAddress,
    uint256 gasLimit,
    uint256 maxSubmissionCost,
    uint256 gasPriceBid
  ) external payable returns (uint256 ticketId);

  /**
   * @notice Dispatch and process message in one transaction.
   * @dev Must compute and return the ID of the retryable ticket that was created.
   * @dev Must emit the `MessageDispatched` and `MessageProcessed` events when successfully dispatched and processed.
   * @param toChainId ID of the receiving chain
   * @param to Address on the receiving chain that will receive `data`
   * @param data Data dispatched to the receiving chain
   * @param refundAddress Address that will receive the `excessFeeRefund` amount if any
   * @param gasLimit Maximum amount of gas required for the message to be executed
   * @param maxSubmissionCost Max gas deducted from user's L2 balance to cover base submission fee
   * @param gasPriceBid Gas price bid for L2 execution
   * @return messageId ID uniquely identifying the message
   * @return ticketId ID of the retryable ticket that was created
   */
  function dispatchAndProcessMessage(
    uint256 toChainId,
    address to,
    bytes calldata data,
    address refundAddress,
    uint256 gasLimit,
    uint256 maxSubmissionCost,
    uint256 gasPriceBid
  ) external payable returns (bytes32 messageId, uint256 ticketId);

  /**
   * @notice Dispatch and process a batch of messages in one transaction.
   * @dev Must compute and return the ID of the retryable ticket that was created.
   * @dev Must emit the `MessageBatchDispatched` and `MessageBatchProcessed` events when successfully dispatched and processed.
   * @param toChainId ID of the receiving chain
   * @param messages Array of Message to dispatch
   * @param refundAddress Address that will receive the `excessFeeRefund` amount if any
   * @param gasLimit Maximum amount of gas required for the message to be executed
   * @param maxSubmissionCost Max gas deducted from user's L2 balance to cover base submission fee
   * @param gasPriceBid Gas price bid for L2 execution
   * @return messageId ID uniquely identifying the message
   * @return ticketId ID of the retryable ticket that was created
   */
  function dispatchAndProcessMessageBatch(
    uint256 toChainId,
    MessageLib.Message[] calldata messages,
    address refundAddress,
    uint256 gasLimit,
    uint256 maxSubmissionCost,
    uint256 gasPriceBid
  ) external payable returns (bytes32 messageId, uint256 ticketId);

  /**
   * @notice Get transaction hash for a single message.
   * @dev The transaction hash is used to ensure that only messages that were dispatched are processed.
   * @param messageId ID uniquely identifying the message that was dispatched
   * @param from Address who dispatched the message
   * @param to Address that will receive the message
   * @param data Data that was dispatched
   * @return Transaction hash
   */
  function getMessageTxHash(
    bytes32 messageId,
    address from,
    address to,
    bytes calldata data
  ) external view returns (bytes32);

  /**
   * @notice Get transaction hash for a batch of messages.
   * @dev The transaction hash is used to ensure that only messages that were dispatched are processed.
   * @param messageId ID uniquely identifying the messages that were dispatched
   * @param from Address who dispatched the messages
   * @param messages Array of messages that were dispatched
   * @return Transaction hash
   */
  function getMessageBatchTxHash(
    bytes32 messageId,
    address from,
    MessageLib.Message[] calldata messages
  ) external view returns (bytes32);
}
