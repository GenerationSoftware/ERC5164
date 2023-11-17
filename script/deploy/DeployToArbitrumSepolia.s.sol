// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";
import { IInbox } from "@arbitrum/nitro-contracts/src/bridge/IInbox.sol";
import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import {
  MessageExecutorArbitrum
} from "../../src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol";
import {
  MessageDispatcherArbitrum
} from "../../src/ethereum-arbitrum/EthereumToArbitrumDispatcher.sol";
import { Greeter } from "../../test/contracts/Greeter.sol";

contract DeployMessageDispatcherToSepolia is Script {
  address public delayedInbox = 0xaAe29B0366299461418F5324a79Afc425BE5ae21;

  function run() public {
    vm.startBroadcast();

    new MessageDispatcherArbitrum(IInbox(delayedInbox), 421614);

    vm.stopBroadcast();
  }
}

contract DeployMessageExecutorToArbitrumSepolia is Script {
  function run() public {
    vm.startBroadcast();

    new MessageExecutorArbitrum();

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying MessageDispatcher and MessageExecutor
contract SetMessageExecutor is DeployedContracts {
  function setMessageExecutor() public {
    MessageDispatcherArbitrum _messageDispatcher = _getMessageDispatcherArbitrumSepolia();
    MessageExecutorArbitrum _messageExecutor = _getMessageExecutorArbitrumSepolia();

    _messageDispatcher.setExecutor(_messageExecutor);
  }

  function run() public {
    vm.startBroadcast();

    setMessageExecutor();

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying MessageDispatcher and MessageExecutor
contract SetMessageDispatcher is DeployedContracts {
  function setMessageDispatcher() public {
    MessageDispatcherArbitrum _messageDispatcher = _getMessageDispatcherArbitrumSepolia();
    MessageExecutorArbitrum _messageExecutor = _getMessageExecutorArbitrumSepolia();

    _messageExecutor.setDispatcher(_messageDispatcher);
  }

  function run() public {
    vm.startBroadcast();

    setMessageDispatcher();

    vm.stopBroadcast();
  }
}

contract DeployGreeterToArbitrumSepolia is DeployedContracts {
  function deployGreeter() public {
    MessageExecutorArbitrum _messageExecutor = _getMessageExecutorArbitrumSepolia();
    new Greeter(address(_messageExecutor), "Hello from L2");
  }

  function run() public {
    vm.startBroadcast();

    deployGreeter();

    vm.stopBroadcast();
  }
}
