// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import {
  IMessageExecutor,
  ISingleMessageExecutor
} from "../interfaces/extensions/ISingleMessageExecutor.sol";
import { IBatchMessageExecutor } from "../interfaces/extensions/IBatchMessageExecutor.sol";

/**
 * @title MessageLib
 * @notice Library to declare and manipulate Message(s).
 */
library MessageLib {
  /* ============ Structs ============ */

  /**
   * @notice Message data structure
   * @param to Address that will be dispatched on the receiving chain
   * @param data Data that will be sent to the `to` address
   */
  struct Message {
    address to;
    bytes data;
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Helper to compute messageId.
   * @param nonce Monotonically increased nonce to ensure uniqueness
   * @param from Address that dispatched the message
   * @param to Address that will receive the message
   * @param data Data that was dispatched
   * @return bytes32 ID uniquely identifying the message that was dispatched
   */
  function computeMessageId(
    uint256 nonce,
    address from,
    address to,
    bytes memory data
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(nonce, from, to, data));
  }

  /**
   * @notice Helper to compute messageId for a batch of messages.
   * @param nonce Monotonically increased nonce to ensure uniqueness
   * @param from Address that dispatched the messages
   * @param messages Array of Message dispatched
   * @return bytes32 ID uniquely identifying the message that was dispatched
   */
  function computeMessageBatchId(
    uint256 nonce,
    address from,
    Message[] memory messages
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(nonce, from, messages));
  }

  /**
   * @notice Helper to encode message for execution by the MessageExecutor.
   * @param to Address that will receive the message
   * @param data Data that will be dispatched
   * @param messageId ID uniquely identifying the message being dispatched
   * @param fromChainId ID of the chain that dispatched the message
   * @param from Address that dispatched the message
   */
  function encodeMessage(
    address to,
    bytes memory data,
    bytes32 messageId,
    uint256 fromChainId,
    address from
  ) internal pure returns (bytes memory) {
    return
      abi.encodeCall(
        ISingleMessageExecutor.executeMessage,
        (to, data, messageId, fromChainId, from)
      );
  }

  /**
   * @notice Helper to encode a batch of messages for execution by the MessageExecutor.
   * @param messages Array of Message that will be dispatched
   * @param messageId ID uniquely identifying the batch of messages being dispatched
   * @param fromChainId ID of the chain that dispatched the batch of messages
   * @param from Address that dispatched the batch of messages
   */
  function encodeMessageBatch(
    Message[] memory messages,
    bytes32 messageId,
    uint256 fromChainId,
    address from
  ) internal pure returns (bytes memory) {
    return
      abi.encodeCall(
        IBatchMessageExecutor.executeMessageBatch,
        (messages, messageId, fromChainId, from)
      );
  }

  /**
   * @notice Execute message from the origin chain.
   * @dev Will revert if `message` has already been executed.
   * @param to Address that will receive the message
   * @param data Data that was dispatched
   * @param messageId ID uniquely identifying message
   * @param fromChainId ID of the chain that dispatched the `message`
   * @param from Address of the sender on the origin chain
   * @param executedMessageId Whether `message` has already been executed or not
   */
  function executeMessage(
    address to,
    bytes memory data,
    bytes32 messageId,
    uint256 fromChainId,
    address from,
    bool executedMessageId
  ) internal {
    if (executedMessageId) {
      revert IMessageExecutor.MessageIdAlreadyExecuted(messageId);
    }

    _requireContract(to);

    (bool _success, bytes memory _returnData) = to.call(
      abi.encodePacked(data, messageId, fromChainId, from)
    );

    if (!_success) {
      revert IMessageExecutor.MessageFailure(messageId, _returnData);
    }
  }

  /**
   * @notice Execute messages from the origin chain.
   * @dev Will revert if `messages` have already been executed.
   * @param messages Array of messages being executed
   * @param messageId Nonce to uniquely identify the messages
   * @param from Address of the sender on the origin chain
   * @param fromChainId ID of the chain that dispatched the `messages`
   * @param executedMessageId Whether `messages` have already been executed or not
   */
  function executeMessageBatch(
    Message[] memory messages,
    bytes32 messageId,
    uint256 fromChainId,
    address from,
    bool executedMessageId
  ) external {
    if (executedMessageId) {
      revert IMessageExecutor.MessageIdAlreadyExecuted(messageId);
    }

    uint256 _messagesLength = messages.length;

    for (uint256 _messageIndex; _messageIndex < _messagesLength; ) {
      Message memory _message = messages[_messageIndex];
      _requireContract(_message.to);

      (bool _success, bytes memory _returnData) = _message.to.call(
        abi.encodePacked(_message.data, messageId, fromChainId, from)
      );

      if (!_success) {
        revert IBatchMessageExecutor.MessageBatchFailure(messageId, _messageIndex, _returnData);
      }

      unchecked {
        _messageIndex++;
      }
    }
  }

  /**
   * @notice Check that the call is being made to a contract.
   * @param to Address to check
   */
  function _requireContract(address to) internal view {
    require(to.code.length > 0, "MessageLib/no-contract-at-to");
  }
}
