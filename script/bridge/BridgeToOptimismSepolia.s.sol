// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import { DeployedContracts } from "../helpers/DeployedContracts.sol";
import {
  MessageDispatcherOptimism
} from "../../src/ethereum-optimism/EthereumToOptimismDispatcher.sol";

import { Greeter } from "../../test/contracts/Greeter.sol";

contract BridgeToOptimismSepolia is DeployedContracts {
  function bridgeToOptimism() public {
    MessageDispatcherOptimism _messageDispatcher = _getMessageDispatcherOptimismSepolia();

    _messageDispatcher.dispatchMessage(
      11155420,
      address(_getGreeterOptimismSepolia()),
      abi.encodeCall(Greeter.setGreeting, ("Hello from L1"))
    );
  }

  function run() public {
    vm.startBroadcast();

    bridgeToOptimism();

    vm.stopBroadcast();
  }
}
