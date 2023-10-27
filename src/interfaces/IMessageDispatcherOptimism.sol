// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import { MessageLib, IMessageDispatcher, IBatchMessageDispatcher } from "./IBatchMessageDispatcher.sol";

/**
 * @title ERC-5164: Cross-Chain Execution Standard
 * @dev IMessageDispatcher interface extended to support a custom gas limit for Optimism.
 * @dev See https://eips.ethereum.org/EIPS/eip-5164
 */
interface IMessageDispatcherOptimism is IBatchMessageDispatcher {
  /**
   * @notice Dispatch and process a message to the receiving chain.
   * @dev Must compute and return an ID uniquely identifying the message.
   * @dev Must emit the `MessageDispatched` event when successfully dispatched.
   * @param toChainId ID of the receiving chain
   * @param to Address on the receiving chain that will receive `data`
   * @param data Data dispatched to the receiving chain
   * @param gasLimit Gas limit at which the message will be executed on Optimism
   * @return ID uniquely identifying the message
   */
  function dispatchMessageWithGasLimit(
    uint256 toChainId,
    address to,
    bytes calldata data,
    uint32 gasLimit
  ) external returns (bytes32);

  /**
   * @notice Dispatch and process `messages` to the receiving chain.
   * @dev Must compute and return an ID uniquely identifying the `messages`.
   * @dev Must emit the `MessageBatchDispatched` event when successfully dispatched.
   * @param toChainId ID of the receiving chain
   * @param messages Array of Message dispatched
   * @param gasLimit Gas limit at which the message will be executed on Optimism
   * @return ID uniquely identifying the `messages`
   */
  function dispatchMessageWithGasLimitBatch(
    uint256 toChainId,
    MessageLib.Message[] calldata messages,
    uint32 gasLimit
  ) external returns (bytes32);
}
