// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.16;

import { DeployedContracts } from "../helpers/DeployedContracts.sol";
import { MessageDispatcherOptimism } from "../../src/ethereum-optimism/EthereumToOptimismDispatcher.sol";

import { Greeter } from "../../test/contracts/Greeter.sol";

contract BridgeToOptimismGoerli is DeployedContracts {
  function bridgeToOptimism() public {
    MessageDispatcherOptimism _messageDispatcher = _getMessageDispatcherOptimismGoerli();

    _messageDispatcher.dispatchMessage(
      420,
      address(_getGreeterOptimismGoerli()),
      abi.encodeCall(Greeter.setGreeting, ("Hello from L1"))
    );
  }

  function run() public {
    vm.broadcast();

    bridgeToOptimism();

    vm.stopBroadcast();
  }
}
