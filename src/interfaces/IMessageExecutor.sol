// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

/**
 * @title ERC-5164: Cross-Chain Execution Standard
 * @dev See https://eips.ethereum.org/EIPS/eip-5164
 */
interface IMessageExecutor {
  /**
   * @notice Emitted when a messageId has already been executed.
   * @param messageId ID uniquely identifying the message or message batch that were re-executed
   */
  error MessageIdAlreadyExecuted(bytes32 messageId);

  /**
   * @notice Emitted if a call to a contract fails.
   * @param messageId ID uniquely identifying the message
   * @param errorData Error data returned by the call
   */
  error MessageFailure(bytes32 messageId, bytes errorData);

  /**
   * @notice Emitted when a message has successfully been executed.
   * @param fromChainId ID of the chain that dispatched the message
   * @param messageId ID uniquely identifying the message that was executed
   */
  event MessageIdExecuted(uint256 indexed fromChainId, bytes32 indexed messageId);
}
