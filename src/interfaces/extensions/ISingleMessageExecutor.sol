// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import { IMessageExecutor } from "../IMessageExecutor.sol";

/**
 * @title SingleMessageExecutor interface
 * @dev IMessageExecutor interface extended to execute a message.
 */
interface ISingleMessageExecutor is IMessageExecutor {
  /**
   * @notice Execute message from the origin chain.
   * @dev Should authenticate that the call has been performed by the bridge transport layer.
   * @dev Must revert if the message fails.
   * @dev Must emit the `MessageIdExecuted` event once the message has been executed.
   * @param to Address that will receive `data`
   * @param data Data forwarded to address `to`
   * @param messageId ID uniquely identifying the message
   * @param fromChainId ID of the chain that dispatched the message
   * @param from Address of the sender on the origin chain
   */
  function executeMessage(
    address to,
    bytes calldata data,
    bytes32 messageId,
    uint256 fromChainId,
    address from
  ) external;
}
