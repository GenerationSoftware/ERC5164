// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { IInbox } from "../interfaces/arbitrum/IInbox.sol";

import "../interfaces/ICrossChainRelayer.sol";

/**
 * @title CrossChainRelayer contract
 * @notice The CrossChainRelayer contract allows a user or contract to send messages to another chain.
 *         It lives on the origin chain and communicates with the `CrossChainExecutor` contract on the receiving chain.
 */
contract CrossChainRelayerArbitrum is ICrossChainRelayer {
  /* ============ Custom Errors ============ */

  /**
   * @notice Custom error emitted if the `gasLimit` passed to `relayCalls`
   *         is greater than the one provided for free on Arbitrum.
   * @param gasLimit Gas limit passed to `relayCalls`
   * @param maxGasLimit Gas limit provided for free on Arbitrum
   */
  error GasLimitTooHigh(uint256 gasLimit, uint256 maxGasLimit);

  /* ============ Events ============ */

  /**
   * @notice Emitted once a message has been processed and put in the Arbitrum inbox.
   *         Using the `ticketId`, this message can be reexecuted for some fixed amount of time if it reverts.
   * @param sender Address who processed the calls
   * @param nonce Id of the message that was sent
   * @param ticketId Id of the newly created retryable ticket
   */
  event ProcessedCalls(address indexed sender, uint256 indexed nonce, uint256 indexed ticketId);

  /* ============ Variables ============ */

  /// @notice Address of the Arbitrum inbox on the origin chain.
  IInbox public immutable inbox;

  /// @notice Address of the executor contract on the receiving chain
  ICrossChainExecutor public executor;

  /// @notice Gas limit provided for free on Arbitrum.
  uint256 public immutable maxGasLimit;

  /// @notice Internal nonce to uniquely idenfity each batch of calls.
  uint256 internal nonce;

  /**
   * @notice Encoded messages queued when calling `relayCalls`.
   *         nonce => encoded message
   * @dev Anyone can send them by calling the `processCalls` function.
   */
  mapping(uint256 => bytes) public messages;

  /* ============ Constructor ============ */

  /**
   * @notice CrossChainRelayer constructor.
   * @param _inbox Address of the Arbitrum inbox
   * @param _maxGasLimit Gas limit provided for free on Arbitrum
   */
  constructor(IInbox _inbox, uint256 _maxGasLimit) {
    require(address(_inbox) != address(0), "Relayer/inbox-not-zero-address");
    require(_maxGasLimit > 0, "Relayer/max-gas-limit-gt-zero");

    inbox = _inbox;
    maxGasLimit = _maxGasLimit;
  }

  /* ============ External Functions ============ */

  /// @inheritdoc ICrossChainRelayer
  function relayCalls(Call[] calldata _calls, uint256 _gasLimit) external payable {
    uint256 _maxGasLimit = maxGasLimit;

    if (_gasLimit > _maxGasLimit) {
      revert GasLimitTooHigh(_gasLimit, _maxGasLimit);
    }

    nonce++;

    uint256 _nonce = nonce;

    messages[_nonce] = abi.encode(
      abi.encodeWithSignature(
        "executeCalls(address,uint256,address,(address,bytes)[])",
        address(this),
        _nonce,
        msg.sender,
        _calls
      ),
      _gasLimit
    );

    emit RelayedCalls(_nonce, msg.sender, executor, _calls, _gasLimit);
  }

  /**
   * @notice Process encoded calls stored in `messages` mapping.
   * @dev Retrieves message and put it in the Arbitrum inbox.
   * @param _nonce Nonce of the message to process
   * @param _maxSubmissionCost Max gas deducted from user's L2 balance to cover base submission fee
   * @param _gasPriceBid Gas price bid for L2 execution
   */
  function processCalls(
    uint256 _nonce,
    uint256 _maxSubmissionCost,
    uint256 _gasPriceBid
  ) external payable returns (uint256) {
    (bytes memory _data, uint256 _gasLimit) = abi.decode(messages[_nonce], (bytes, uint256));

    uint256 _ticketID = inbox.createRetryableTicket{ value: msg.value }(
      address(executor),
      0,
      _maxSubmissionCost,
      msg.sender,
      msg.sender,
      _gasLimit,
      _gasPriceBid,
      _data
    );

    emit ProcessedCalls(msg.sender, _nonce, _ticketID);

    return _ticketID;
  }

  /**
   * @notice Set executor contract address.
   * @dev Will revert if it has already been set.
   * @param _executor Address of the executor contract on the receiving chain
   */
  function setExecutor(ICrossChainExecutor _executor) external {
    require(address(executor) == address(0), "Relayer/executor-already-set");
    executor = _executor;
  }
}
