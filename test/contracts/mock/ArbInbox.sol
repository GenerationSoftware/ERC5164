// SPDX-License-Identifier: GPL-3.0
// Source: https://github.com/OffchainLabs/nitro/blob/691f00a06ff301304c464d9fb379da0fcd82bedc/contracts/src/mocks/InboxStub.sol

pragma solidity ^0.8.16;

import { IBridge } from "@arbitrum/nitro-contracts/src/bridge/IBridge.sol";
import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";
import { ISequencerInbox } from "@arbitrum/nitro-contracts/src/bridge/ISequencerInbox.sol";

import { L2_MSG } from "@arbitrum/nitro-contracts/src/libraries/MessageTypes.sol";

contract ArbInbox is IInbox {
  IBridge public override bridge;
  ISequencerInbox public override sequencerInbox;

  bool public paused;

  function pause() external pure {
    revert("NOT IMPLEMENTED");
  }

  function unpause() external pure {
    revert("NOT IMPLEMENTED");
  }

  function initialize(IBridge _bridge, ISequencerInbox) external {
    require(address(bridge) == address(0), "ALREADY_INIT");
    bridge = _bridge;
  }

  /**
   * @notice Send a generic L2 message to the chain
   * @dev This method is an optimization to avoid having to emit the entirety of the messageData in a log. Instead validators are expected to be able to parse the data from the transaction's input
   * @param messageData Data of the message being sent
   */
  function sendL2MessageFromOrigin(bytes calldata messageData) external returns (uint256) {
    // solhint-disable-next-line avoid-tx-origin
    require(msg.sender == tx.origin, "origin only");
    uint256 msgNum = deliverToBridge(L2_MSG, msg.sender, keccak256(messageData));
    emit InboxMessageDeliveredFromOrigin(msgNum);
    return msgNum;
  }

  /**
   * @notice Send a generic L2 message to the chain
   * @dev This method can be used to send any type of message that doesn't require L1 validation
   * @param messageData Data of the message being sent
   */
  function sendL2Message(bytes calldata messageData) external override returns (uint256) {
    uint256 msgNum = deliverToBridge(L2_MSG, msg.sender, keccak256(messageData));
    emit InboxMessageDelivered(msgNum, messageData);
    return msgNum;
  }

  function deliverToBridge(
    uint8 kind,
    address sender,
    bytes32 messageDataHash
  ) internal returns (uint256) {
    return bridge.enqueueDelayedMessage{ value: msg.value }(kind, sender, messageDataHash);
  }

  function sendUnsignedTransaction(
    uint256,
    uint256,
    uint256,
    address,
    uint256,
    bytes calldata
  ) external pure override returns (uint256) {
    revert("NOT_IMPLEMENTED");
  }

  function sendContractTransaction(
    uint256,
    uint256,
    address,
    uint256,
    bytes calldata
  ) external pure override returns (uint256) {
    revert("NOT_IMPLEMENTED");
  }

  function sendL1FundedUnsignedTransaction(
    uint256,
    uint256,
    uint256,
    address,
    bytes calldata
  ) external payable override returns (uint256) {
    revert("NOT_IMPLEMENTED");
  }

  function sendL1FundedContractTransaction(
    uint256,
    uint256,
    address,
    bytes calldata
  ) external payable override returns (uint256) {
    revert("NOT_IMPLEMENTED");
  }

  function generateRandomNumber() public view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
  }

  function createRetryableTicket(
    address,
    uint256,
    uint256,
    address,
    address,
    uint256,
    uint256,
    bytes calldata
  ) external payable override returns (uint256) {
    return generateRandomNumber();
  }

  function unsafeCreateRetryableTicket(
    address,
    uint256,
    uint256,
    address,
    address,
    uint256,
    uint256,
    bytes calldata
  ) external payable override returns (uint256) {
    revert("NOT_IMPLEMENTED");
  }

  function sendL1FundedUnsignedTransactionToFork(
    uint256,
    uint256,
    uint256,
    address,
    bytes calldata
  ) external payable returns (uint256) {
    revert("NOT_IMPLEMENTED");
  }

  function sendUnsignedTransactionToFork(
    uint256,
    uint256,
    uint256,
    address,
    uint256,
    bytes calldata
  ) external pure returns (uint256) {
    revert("NOT_IMPLEMENTED");
  }

  function sendWithdrawEthToFork(
    uint256,
    uint256,
    uint256,
    uint256,
    address
  ) external pure returns (uint256) {
    revert("NOT_IMPLEMENTED");
  }

  function depositEth() external payable override returns (uint256) {
    revert("NOT_IMPLEMENTED");
  }

  function postUpgradeInit(IBridge _bridge) external {}

  function calculateRetryableSubmissionFee(
    uint256,
    uint256
  ) external pure override returns (uint256) {
    revert("NOT_IMPLEMENTED");
  }
}
