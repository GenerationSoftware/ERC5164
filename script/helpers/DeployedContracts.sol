// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import "solidity-stringutils/strings.sol";

import {
  MessageDispatcherOptimism
} from "../../src/ethereum-optimism/EthereumToOptimismDispatcher.sol";
import {
  MessageExecutorOptimism
} from "../../src/ethereum-optimism/EthereumToOptimismExecutor.sol";

import {
  MessageDispatcherPolygon
} from "../../src/ethereum-polygon/EthereumToPolygonDispatcher.sol";
import { MessageExecutorPolygon } from "../../src/ethereum-polygon/EthereumToPolygonExecutor.sol";

import {
  MessageDispatcherArbitrum
} from "../../src/ethereum-arbitrum/EthereumToArbitrumDispatcher.sol";
import {
  MessageExecutorArbitrum
} from "../../src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol";

import { Greeter } from "../../test/contracts/Greeter.sol";

// Testnet deployment paths
string constant OPTIMISM_SEPOLIA_PATH = "/broadcast/DeployToOptimismSepolia.s.sol/11155420/";
string constant MUMBAI_PATH = "/broadcast/DeployToMumbai.s.sol/80001/";
string constant ARBITRUM_SEPOLIA_PATH = "/broadcast/DeployToArbitrumSepolia.s.sol/421614/";

abstract contract DeployedContracts is Script {
  using strings for *;
  using stdJson for string;

  /* ============ Helpers ============ */

  function _getDeploymentArtifacts(
    string memory _deploymentArtifactsPath
  ) internal returns (string[] memory) {
    string[] memory inputs = new string[](4);
    inputs[0] = "ls";
    inputs[1] = "-m";
    inputs[2] = "-r";
    inputs[3] = string.concat(vm.projectRoot(), _deploymentArtifactsPath);
    bytes memory res = vm.ffi(inputs);

    // Slice ls result
    strings.slice memory s = string(res).toSlice();

    // Remove directory jargon at the beginning of the slice (Fix for Windows Git Bash)
    strings.slice memory dirEnd = "/:".toSlice();
    strings.slice memory sWithoutDirPrefix = s.copy().find(dirEnd).beyond(dirEnd);
    if (!sWithoutDirPrefix.empty()) s = sWithoutDirPrefix;

    // Remove newline and push into array
    strings.slice memory delim = ", ".toSlice();
    strings.slice memory sliceNewline = "\n".toSlice();
    string[] memory filesName = new string[](s.count(delim) + 1);

    for (uint256 i = 0; i < filesName.length; i++) {
      filesName[i] = s.split(delim).beyond(sliceNewline).toString();
    }

    return filesName;
  }

  function _getContractAddress(
    string memory _contractName,
    string memory _artifactsPath,
    string memory _errorMsg
  ) internal returns (address) {
    string[] memory filesName = _getDeploymentArtifacts(_artifactsPath);

    uint256 filesNameLength = filesName.length;

    // Loop through deployment artifacts and find latest deployed `_contractName` address
    for (uint256 j; j < filesNameLength; j++) {
      string memory filePath = string.concat(vm.projectRoot(), _artifactsPath, filesName[j]);
      string memory jsonFile = vm.readFile(filePath);
      string memory contractName = abi.decode(
        stdJson.parseRaw(jsonFile, ".transactions[0].contractName"),
        (string)
      );

      if (
        keccak256(abi.encodePacked((contractName))) == keccak256(abi.encodePacked((_contractName)))
      ) {
        return
          abi.decode(stdJson.parseRaw(jsonFile, ".transactions[0].contractAddress"), (address));
      }
    }

    revert(_errorMsg);
  }

  /* ============ Getters ============ */

  /* ============ Optimism ============ */
  /* ============ Mainnet ============ */
  function _getMessageDispatcherOptimism() internal returns (MessageDispatcherOptimism) {
    return
      MessageDispatcherOptimism(
        _getContractAddress(
          "MessageDispatcherOptimism",
          "/broadcast/DeployToOptimism.s.sol/1/",
          "dispatcher-not-found"
        )
      );
  }

  function _getMessageExecutorOptimism() internal returns (MessageExecutorOptimism) {
    return
      MessageExecutorOptimism(
        _getContractAddress(
          "MessageExecutorOptimism",
          "/broadcast/DeployToOptimism.s.sol/10/",
          "executor-not-found"
        )
      );
  }

  /* ============ Testnet ============ */
  function _getMessageDispatcherOptimismSepolia() internal returns (MessageDispatcherOptimism) {
    return
      MessageDispatcherOptimism(
        _getContractAddress(
          "MessageDispatcherOptimism",
          "/broadcast/DeployToOptimismSepolia.s.sol/11155111/",
          "dispatcher-not-found"
        )
      );
  }

  function _getMessageExecutorOptimismSepolia() internal returns (MessageExecutorOptimism) {
    return
      MessageExecutorOptimism(
        _getContractAddress("MessageExecutorOptimism", OPTIMISM_SEPOLIA_PATH, "executor-not-found")
      );
  }

  function _getGreeterOptimismSepolia() internal returns (Greeter) {
    return Greeter(_getContractAddress("Greeter", OPTIMISM_SEPOLIA_PATH, "greeter-not-found"));
  }

  /* ============ Polygon ============ */
  function _getMessageDispatcherPolygon() internal returns (MessageDispatcherPolygon) {
    return
      MessageDispatcherPolygon(
        _getContractAddress(
          "MessageDispatcherPolygon",
          "/broadcast/DeployToMumbai.s.sol/5/",
          "dispatcher-not-found"
        )
      );
  }

  function _getMessageExecutorPolygon() internal returns (MessageExecutorPolygon) {
    return
      MessageExecutorPolygon(
        _getContractAddress("MessageExecutorPolygon", MUMBAI_PATH, "executor-not-found")
      );
  }

  function _getGreeterPolygon() internal returns (Greeter) {
    return Greeter(_getContractAddress("Greeter", MUMBAI_PATH, "greeter-not-found"));
  }

  /* ============ Arbitrum ============ */
  /* ============ Testnet ============ */
  function _getMessageDispatcherArbitrumSepolia() internal returns (MessageDispatcherArbitrum) {
    return
      MessageDispatcherArbitrum(
        _getContractAddress(
          "MessageDispatcherArbitrum",
          "/broadcast/DeployToArbitrumSepolia.s.sol/11155111/",
          "dispatcher-not-found"
        )
      );
  }

  function _getMessageExecutorArbitrumSepolia() internal returns (MessageExecutorArbitrum) {
    return
      MessageExecutorArbitrum(
        _getContractAddress("MessageExecutorArbitrum", ARBITRUM_SEPOLIA_PATH, "executor-not-found")
      );
  }

  function _getGreeterArbitrumSepolia() internal returns (Greeter) {
    return Greeter(_getContractAddress("Greeter", ARBITRUM_SEPOLIA_PATH, "greeter-not-found"));
  }
}
