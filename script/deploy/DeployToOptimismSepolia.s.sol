// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";

import { ICrossDomainMessenger } from "../../src/vendor/optimism/ICrossDomainMessenger.sol";
import { DeployedContracts } from "../helpers/DeployedContracts.sol";

import {
  MessageDispatcherOptimism
} from "../../src/ethereum-optimism/EthereumToOptimismDispatcher.sol";
import {
  MessageExecutorOptimism
} from "../../src/ethereum-optimism/EthereumToOptimismExecutor.sol";
import { Greeter } from "../../test/contracts/Greeter.sol";

contract DeployMessageDispatcherToSepolia is Script {
  address public proxyOVML1CrossDomainMessenger = 0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef;

  function run() public {
    vm.startBroadcast();

    new MessageDispatcherOptimism(
      ICrossDomainMessenger(proxyOVML1CrossDomainMessenger),
      11155420,
      1_920_000
    );

    vm.stopBroadcast();
  }
}

contract DeployMessageExecutorToOptimismSepolia is Script {
  address public l2CrossDomainMessenger = 0x4200000000000000000000000000000000000007;

  function run() public {
    vm.startBroadcast();

    new MessageExecutorOptimism(ICrossDomainMessenger(l2CrossDomainMessenger));

    vm.stopBroadcast();
  }
}

/// @dev Needs to be run after deploying MessageDispatcher and MessageExecutor
contract SetMessageExecutor is DeployedContracts {
  function setMessageExecutor() public {
    MessageDispatcherOptimism _messageDispatcher = _getMessageDispatcherOptimismSepolia();
    MessageExecutorOptimism _messageExecutor = _getMessageExecutorOptimismSepolia();

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
    MessageDispatcherOptimism _messageDispatcher = _getMessageDispatcherOptimismSepolia();
    MessageExecutorOptimism _messageExecutor = _getMessageExecutorOptimismSepolia();

    _messageExecutor.setDispatcher(_messageDispatcher);
  }

  function run() public {
    vm.startBroadcast();

    setMessageDispatcher();

    vm.stopBroadcast();
  }
}

contract DeployGreeterToOptimismSepolia is DeployedContracts {
  function deployGreeter() public {
    MessageExecutorOptimism _messageExecutor = _getMessageExecutorOptimismSepolia();
    new Greeter(address(_messageExecutor), "Hello from L2");
  }

  function run() public {
    vm.startBroadcast();

    deployGreeter();

    vm.stopBroadcast();
  }
}
