// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import { IMessageDispatcher } from "../IMessageDispatcher.sol";
import { MessageLib } from "../../libraries/MessageLib.sol";

/**
 * @title ERC-5164: Cross-Chain Execution Standard, optional BatchMessageDispatcher extension
 * @dev IMessageDispatcher interface extended to support batch messaging.
 * @dev See https://eips.ethereum.org/EIPS/eip-5164
 */
interface IBatchMessageDispatcher is IMessageDispatcher {
  /**
   * @notice Emitted when a batch of messages has successfully been dispatched to the executor chain.
   * @param messageId ID uniquely identifying the messages
   * @param from Address that dispatched the messages
   * @param toChainId ID of the chain receiving the messages
   * @param messages Array of Message that was dispatched
   */
  event MessageBatchDispatched(
    bytes32 indexed messageId,
    address indexed from,
    uint256 indexed toChainId,
    MessageLib.Message[] messages
  );

  /**
   * @notice Dispatch `messages` to the receiving chain.
   * @dev Must compute and return an ID uniquely identifying the `messages`.
   * @dev Must emit the `MessageBatchDispatched` event when successfully dispatched.
   * @param toChainId ID of the receiving chain
   * @param messages Array of Message dispatched
   * @return ID uniquely identifying the `messages`
   */
  function dispatchMessageBatch(
    uint256 toChainId,
    MessageLib.Message[] calldata messages
  ) external returns (bytes32);
}
