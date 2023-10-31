// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import { IMessageExecutor } from "../IMessageExecutor.sol";
import { MessageLib } from "../../libraries/MessageLib.sol";

/**
 * @title BatchMessageExecutor interface
 * @dev IMessageExecutor interface extended to support batch messaging.
 * @notice BatchMessageExecutor interface of the ERC-5164 standard as defined in the EIP.
 */
interface IBatchMessageExecutor is IMessageExecutor {
  /**
   * @notice Emitted if a call to a contract fails inside a batch of messages.
   * @param messageId ID uniquely identifying the batch of messages
   * @param messageIndex Index of the message
   * @param errorData Error data returned by the call
   */
  error MessageBatchFailure(bytes32 messageId, uint256 messageIndex, bytes errorData);

  /**
   * @notice Execute a batch messages from the origin chain.
   * @dev Should authenticate that the call has been performed by the bridge transport layer.
   * @dev Must revert if one of the messages fails.
   * @dev Must emit the `MessageIdExecuted` event once messages have been executed.
   * @param messages Array of messages being executed
   * @param messageId ID uniquely identifying the messages
   * @param fromChainId ID of the chain that dispatched the messages
   * @param from Address of the sender on the origin chain
   */
  function executeMessageBatch(
    MessageLib.Message[] calldata messages,
    bytes32 messageId,
    uint256 fromChainId,
    address from
  ) external;
}
