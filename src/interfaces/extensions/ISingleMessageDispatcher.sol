// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import { IMessageDispatcher } from "../IMessageDispatcher.sol";

/**
 * @title SingleMessageDispatcher interface
 * @dev IMessageDispatcher interface extended to retrieve the MessageExecutor contract address.
 */
interface ISingleMessageDispatcher is IMessageDispatcher {
  /**
   * @notice Retrieves address of the MessageExecutor contract on the receiving chain.
   * @dev Must revert if `toChainId` is not supported.
   * @param toChainId ID of the chain with which MessageDispatcher is communicating
   * @return MessageExecutor contract address
   */
  function getMessageExecutorAddress(uint256 toChainId) external returns (address);
}
