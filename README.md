# ERC-5164

EIP-5164 specifies how smart contracts on one chain can message contracts on another. Transport layers, such as bridges, will have their own EIP-5164 implementations. This repository includes implementations for: Ethereum to Polygon, Ethereum to Optimism, and Ethereum to Arbitrum. All three use the 'native' bridge solutions.

The EIP is currently in the Review stage: https://eips.ethereum.org/EIPS/eip-5164

This repository includes 5164 wrappers for popular L2s. It has been [audited by Code Arena](https://gov.pooltogether.com/t/c4-audit-erc-5164/2708). Here are the [findings](https://github.com/code-423n4/2022-12-pooltogether-findings).

Feedback and PR are welcome!

## How to use

To use ERC-5164 to send messages your contract code will need to:

- On the sending chain, send a message to the MessageDispatcher `dispatchMessage` or `dispatchMessageBatch` function
- Listen for messages from the corresponding MessageExecutor(s) on the receiving chain.

_The listener will need to be able to unpack the original sender address (it's appended to calldata). We recommend inheriting from the included [`ExecutorAware.sol`](./src/abstract/ExecutorAware.sol) contract._

**Note**

For most bridges, you only have to call `dispatchMessage` or `dispatchMessageBatch` to have messages executed by the MessageExecutor. However, Arbitrum requires an EOA to process the dispatch. We will review this below.

## How it works

1. A smart contract on the sending chain calls `dispatchMessage` or `dispatchMessageBatch` on the MessageDispatcher..
2. The corresponding MessageExecutor(s) on the receiving chain will execute the message or batch of Message structs. The address of the original dispatcher on the sending chain is appended to the message data.
3. Any smart contract can receive messages from a MessageExecutor, but they should use the original dispatcher address for authentication.

**Note: this specification does not require messages to be executed in order**

## Dispatching

### Dispatch a message

To dispatch a message from Ethereum to the L2 of your choice, you have to interact with the [IMessageDispatcher](./src/interfaces/IMessageDispatcher.sol) contract and call the following function.

```solidity
/**
 * @notice Dispatch a message to the receiving chain.
 * @dev Must compute and return an ID uniquely identifying the message.
 * @dev Must emit the `MessageDispatched` event when successfully dispatched.
 * @param toChainId ID of the receiving chain
 * @param to Address on the receiving chain that will receive `data`
 * @param data Data dispatched to the receiving chain
 * @return bytes32 ID uniquely identifying the message
 */
function dispatchMessage(
  uint256 toChainId,
  address to,
  bytes calldata data
) external returns (bytes32);
```

- `toChainId`: ID of the chain to which you want to dispatch the message
- `to`: address of the contract that will receive the message
- `data`: message that you want to be executed on L2

### Dispatch a batch messages

To dispatch a batch of messages from Ethereum to the L2 of your choice, you have to interact with the [IBatchMessageDispatcher](./src/interfaces/extensions/IBatchMessageDispatcher.sol) contract and call the following function.

```solidity
/**
 * @notice Dispatch `messages` to the receiving chain.
 * @dev Must compute and return an ID uniquely identifying the `messages`.
 * @dev Must emit the `MessageBatchDispatched` event when successfully dispatched.
 * @param toChainId ID of the receiving chain
 * @param messages Array of Message dispatched
 * @return bytes32 ID uniquely identifying the `messages`
 */
function dispatchMessageBatch(
  uint256 toChainId,
  MessageLib.Message[] calldata messages
) external returns (bytes32);
```

- `toChainId`: ID of the chain to which you want to dispatch the message
- `messages`: array of Message that you want to be executed on L2

```solidity
/**
 * @notice Message data structure
 * @param to Address that will be dispatched on the receiving chain
 * @param data Data that will be sent to the `to` address
 */
struct Message {
  address to;
  bytes data;
}
```

#### Example

```solidity
MessageDispatcherOptimism _messageDispatcher = 0x3F3623aB84a86410096f53051b82aA41773A4480;
address _greeter = 0x19c8f7B8BA7a151d6825924446A596b6084a36ae;

_messageDispatcher.dispatchMessage(
  420,
  _greeter,
  abi.encodeCall(Greeter.setGreeting, ("Hello from L1"))
);
```

Code:

- [script/bridge/BridgeToOptimismGoerli.s.sol](script/bridge/BridgeToOptimismGoerli.s.sol)
- [script/bridge/BridgeToMumbai.s.sol](script/bridge/BridgeToMumbai.s.sol)

### Arbitrum Dispatch

Arbitrum requires an EOA to submit a bridge transaction. The Ethereum to Arbitrum ERC-5164 MessageDispatcher `dispatchMessage` implementation is therefore split into two actions:

1. Message to MessageDispatcher `dispatchMessage` is fingerprinted and stored along with their `messageId`.
2. Anyone may call MessageDispatcher `processMessage` to send a previously fingerprinted dispatched message.

The `processMessage` function requires the same transaction parameters as the Arbitrum bridge. The [Arbitrum SDK](https://github.com/offchainlabs/arbitrum-sdk) is needed to properly estimate the gas required to execute the message on L2.

```solidity
/**
 * @notice Process message that has been dispatched.
 * @dev The transaction hash must match the one stored in the `dispatched` mapping.
 * @dev `_from` is passed as `_callValueRefundAddress` cause this address can cancel the retryable ticket.
 * @dev We store `_message` in memory to avoid a stack too deep error.
 * @param _messageId ID of the message to process
 * @param _from Address who dispatched the `_data`
 * @param _to Address that will receive the message
 * @param _data Data that was dispatched
 * @param _refundAddress Address that will receive the `excessFeeRefund` amount if any
 * @param _gasLimit Maximum amount of gas required for the `_messages` to be executed
 * @param _maxSubmissionCost Max gas deducted from user's L2 balance to cover base submission fee
 * @param _gasPriceBid Gas price bid for L2 execution
 * @return uint256 ID of the retryable ticket that was created
 */
function processMessage(
  bytes32 messageId,
  address from,
  address to,
  bytes calldata data,
  address refundAddress,
  uint256 gasLimit,
  uint256 maxSubmissionCost,
  uint256 gasPriceBid
) external payable returns (uint256);
```

#### Arbitrum Dispatch Example

```typescript
  const greeterAddress = await getContractAddress('Greeter', ARBITRUM_GOERLI_CHAIN_ID, 'Forge');

  const greeting = 'Hello from L1';
  const messageData = new Interface(['function setGreeting(string)']).encodeFunctionData(
    'setGreeting',
    [greeting],
  );

  const nextNonce = (await messageDispatcherArbitrum.nonce()).add(1);

  const encodedMessageId = keccak256(
    defaultAbiCoder.encode(
      ['uint256', 'address', 'address', 'bytes'],
      [nextNonce, deployer, greeterAddress, messageData],
    ),
  );

  const executeMessageData = new Interface([
    'function executeMessage(address,bytes,bytes32,uint256,address)',
  ]).encodeFunctionData('executeMessage', [
    greeterAddress,
    messageData,
    encodedMessageId,
    GOERLI_CHAIN_ID,
    deployer,
  ]);

...

  const { deposit, gasLimit, maxSubmissionCost } = await l1ToL2MessageGasEstimate.estimateAll(
    {
      from: messageDispatcherArbitrumAddress,
      to: messageExecutorAddress,
      l2CallValue: BigNumber.from(0),
      excessFeeRefundAddress: deployer,
      callValueRefundAddress: deployer,
      data: executeMessageData,
    },
    baseFee,
    l1Provider,
  );

  await messageDispatcherArbitrum.dispatchMessage(
    ARBITRUM_GOERLI_CHAIN_ID,
    greeterAddress,
    messageData,
  );

...

await messageDispatcherArbitrum.processMessage(
    messageId,
    deployer,
    greeterAddress,
    messageData,
    deployer,
    gasLimit,
    maxSubmissionCost,
    gasPriceBid,
    {
      value: deposit,
    },
  );
```

Code: [script/bridge/BridgeToArbitrumGoerli.ts](script/bridge/BridgeToArbitrumGoerli.ts)

## Execution

#### Execute message

Once the message has been bridged it will be executed by the [MessageExecutor](./src/interfaces/IMessageExecutor.sol) contract.

#### Authenticate messages

To ensure that the messages originate from the MessageExecutor contract, your contracts can inherit from the [ExecutorAware](./src/abstract/ExecutorAware.sol) abstract contract.

It makes use of [EIP-2771](https://eips.ethereum.org/EIPS/eip-2771) to authenticate the message forwarder (i.e. the MessageExecutor) and has helper functions to extract from the calldata the original sender and the `messageId` of the dispatched message.

```solidity
/**
 * @notice Check which executor this contract trust.
 * @param _executor Address to check
 */
function isTrustedExecutor(address _executor) public view returns (bool);

/**
  * @notice Retrieve messageId from message data.
  * @return _msgDataMessageId ID uniquely identifying the message that was executed
  */
function _messageId() internal pure returns (bytes32 _msgDataMessageId)

/**
  * @notice Retrieve fromChainId from message data.
  * @return _msgDataFromChainId ID of the chain that dispatched the messages
  */
function _fromChainId() internal pure returns (uint256 _msgDataFromChainId);

/**
 * @notice Retrieve signer address from message data.
 * @return _signer Address of the signer
 */
function _msgSender() internal view returns (address payable _signer);

```

## Deployed Contracts

### Mainnet

#### Ethereum -> Optimism

| Network  | Contract                                                                                     | Address                                                                                                                          |
| -------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum | [EthereumToOptimismDispatcher.sol](./src/ethereum-optimism/EthereumToOptimismDispatcher.sol) | [0x2A34E6cae749876FB8952aD7d2fA486b00F0683F](https://etherscan.io/address/0x2A34E6cae749876FB8952aD7d2fA486b00F0683F)            |
| Optimism | [EthereumToOptimismExecutor](./src/ethereum-optimism/EthereumToOptimismExecutor.sol)         | [0x139f6dD114a9C45Ba43eE22C5e03c53de0c13225](https://optimistic.etherscan.io/address/0x139f6dD114a9C45Ba43eE22C5e03c53de0c13225) |

### Testnet

#### Ethereum Sepolia -> Arbitrum Sepolia

| Network          | Contract                                                                                     | Address                                                                                                                       |
| ---------------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Sepolia | [EthereumToArbitrumDispatcher.sol](./src/ethereum-arbitrum/EthereumToArbitrumDispatcher.sol) | [0x9887b04Fdf205Fef072d6F325c247264eD34ACF0](https://sepolia.etherscan.io/address/0x9887b04Fdf205Fef072d6F325c247264eD34ACF0) |
| Arbitrum Sepolia | [EthereumToArbitrumExecutor](./src/ethereum-arbitrum/EthereumToArbitrumExecutor.sol)         | [0x2B3E6b5c9a6Bdb0e595896C9093fce013490abbD](https://sepolia.arbiscan.io/address/0x2B3E6b5c9a6Bdb0e595896C9093fce013490abbD)  |
| Arbitrum Sepolia | [Greeter](./test/contracts/Greeter.sol)                                                      | [0xdA9C65A10a8EF5Ed3d3aAE9a63FD1Be99Cd88f0c](https://sepolia.arbiscan.io/address/0xdA9C65A10a8EF5Ed3d3aAE9a63FD1Be99Cd88f0c)  |

#### Ethereum Sepolia -> Optimism Sepolia

| Network          | Contract                                                                                     | Address                                                                                                                                |
| ---------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Sepolia | [EthereumToOptimismDispatcher.sol](./src/ethereum-optimism/EthereumToOptimismDispatcher.sol) | [0x2aeB429f7d8c00983E033087Dd5a363AbA2AC55f](https://sepolia.etherscan.io/address/0x2aeB429f7d8c00983E033087Dd5a363AbA2AC55f)          |
| Optimism Sepolia | [EthereumToOptimismExecutor](./src/ethereum-optimism/EthereumToOptimismExecutor.sol)         | [0x6A501383A61ebFBc143Fc4BD41A2356bA71A6964](https://sepolia-optimism.etherscan.io/address/0x6A501383A61ebFBc143Fc4BD41A2356bA71A6964) |
| Optimism Sepolia | [Greeter](./test/contracts/Greeter.sol)                                                      | [0x8537C5a9AAd3ec1D31a84e94d19FcFC681E83ED0](https://sepolia-optimism.etherscan.io/address/0x8537C5a9AAd3ec1D31a84e94d19FcFC681E83ED0) |

#### Ethereum Goerli -> Polygon Mumbai

| Network         | Contract                                                                              | Address                                                                                                                         |
| --------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | [EthereumToPolygonDispatcher](./src/ethereum-polygon/EthereumToPolygonDispatcher.sol) | [0xBA8d8a0554dFd7F7CCf3cEB47a88d711e6a65F5b](https://goerli.etherscan.io/address/0xBA8d8a0554dFd7F7CCf3cEB47a88d711e6a65F5b)    |
| Polygon Mumbai  | [EthereumToPolygonExecutor](./src/ethereum-polygon/EthereumToPolygonExecutor.sol)     | [0x784fFd1E27FA32804bD0a170dc7A277399AbD361](https://mumbai.polygonscan.com/address/0x784fFd1E27FA32804bD0a170dc7A277399AbD361) |
| Polygon Mumbai  | [Greeter](./test/contracts/Greeter.sol)                                               | [0x3b73dCeC4447DDB1303F9b766BbBeB87aFAf22a3](https://mumbai.polygonscan.com/address/0x3b73dCeC4447DDB1303F9b766BbBeB87aFAf22a3) |

## Development

### Installation

You may have to install the following tools to use this repository:

- [Yarn](https://yarnpkg.com/getting-started/install) to handle dependencies
- [Foundry](https://github.com/foundry-rs/foundry) to compile and test contracts
- [direnv](https://direnv.net/) to handle environment variables
- [lcov](https://github.com/linux-test-project/lcov) to generate the code coverage report

Install dependencies:

```
yarn
```

### Env

Copy `.envrc.example` and write down the env variables needed to run this project.

```
cp .envrc.example .envrc
```

Once your env variables are setup, load them with:

```
direnv allow
```

### Compile

Run the following command to compile the contracts:

```
yarn compile
```

### Test

We use [Hardhat](https://hardhat.org) to run Arbitrum fork tests. All other tests are being written in Solidity and make use of [Forge Standard Library](https://github.com/foundry-rs/forge-std).

To run Forge unit and fork tests:

```
yarn test
```

To run Arbitrum fork tests, use the following commands:

- Fork tests to dispatch messages from Ethereum to Arbitrum:

  ```
  yarn fork:startDispatchMessageBatchArbitrumMainnet
  ```

- Fork tests to execute messages on Arbitrum:

  ```
  yarn fork:startExecuteMessageBatchArbitrumMainnet
  ```

### Coverage

Forge is used for coverage, run it with:

```
yarn coverage
```

You can then consult the report by opening `coverage/index.html`:

```
open coverage/index.html
```

### Deployment

You can use the following commands to deploy on mainnet and testnet.

#### Mainnet

##### Ethereum to Optimism bridge

```
yarn deploy:optimism
```

#### Testnet

##### Ethereum Sepolia to Arbitrum Sepolia bridge

```
yarn deploy:arbitrumSepolia
```

##### Ethereum Sepolia to Optimism Sepolia bridge

```
yarn deploy:optimismSepolia
```

##### Ethereum Goerli to Polygon Mumbai bridge

```
yarn deploy:mumbai
```

### Bridging

You can use the following commands to bridge from Ethereum to a layer 2 of your choice.

It will set the greeting message in the [Greeter](./test/contracts/Greeter.sol) contract to `Hello from L1` instead of `Hello from L2`.

#### Ethereum Sepolia to Arbitrum Sepolia

```
yarn bridge:arbitrumSepolia
```

It takes about 15 minutes for the message to be bridged to Arbitrum Sepolia.

##### Example transaction

| Network         | Message         | Transaction hash                                                                                                                                                        |
| --------------- | --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | dispatchMessage | [0xfdb983cad74d5d95c2ffdbb38cde50fefbe78280416bbe44de35485c213909d5](https://goerli.etherscan.io/tx/0xfdb983cad74d5d95c2ffdbb38cde50fefbe78280416bbe44de35485c213909d5) |
| Ethereum Goerli | processMessage  | [0x4effcda5e729a2943a86bd1317a784644123388bb4fd7ea207e70ec3a360ab60](https://goerli.etherscan.io/tx/0x4effcda5e729a2943a86bd1317a784644123388bb4fd7ea207e70ec3a360ab60) |
| Arbitrum Goerli | executeMessage  | [0x0883252887d34a4a545a20e252e55c712807d1707438cf6e8503a99a32357024](https://goerli.arbiscan.io/tx/0x0883252887d34a4a545a20e252e55c712807d1707438cf6e8503a99a32357024)  |

#### Ethereum Sepolia to Optimism Sepolia

```
yarn bridge:optimismSepolia
```

It takes about 5 minutes for the message to be bridged to Optimism Sepolia.

##### Example transaction

| Network          | Message         | Transaction hash                                                                                                                                                                                                                                                    |
| ---------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Sepolia | dispatchMessage | [0xbfef5bbbe67454c75545739cf69e03d0e947158295fe052d468c0000729f0019](https://sepolia.etherscan.io/tx/0xbfef5bbbe67454c75545739cf69e03d0e947158295fe052d468c0000729f0019)                                                                                            |
| Optimism Sepolia | executeMessage  | [https://sepolia-optimism.etherscan.io/tx/0x5c68c4b7912771e075437a2d170789ba8d36084e1ccd89c4fd18e5544937a0b8](https://sepolia-optimism.etherscan.io/tx/https://sepolia-optimism.etherscan.io/tx/0x5c68c4b7912771e075437a2d170789ba8d36084e1ccd89c4fd18e5544937a0b8) |

#### Ethereum Goerli to Polygon Mumbai

```
yarn bridge:mumbai
```

It takes about 30 minutes for the message to be bridged to Mumbai.

##### Example transaction

| Network         | Message         | Transaction hash                                                                                                                                                           |
| --------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Goerli | dispatchMessage | [0x856355f3df4f94bae2075abbce57163af95637ae9c65bbe231f170d9cdf251c9](https://goerli.etherscan.io/tx/0x856355f3df4f94bae2075abbce57163af95637ae9c65bbe231f170d9cdf251c9)    |
| Polygon Mumbai  | executeMessage  | [0x78aff3ff10b43169ce468bf88da79560724ea292290c336cd84a43fdd8441c52](https://mumbai.polygonscan.com/tx/0x78aff3ff10b43169ce468bf88da79560724ea292290c336cd84a43fdd8441c52) |

### Code quality

[Prettier](https://prettier.io) is used to format TypeScript and Solidity code. Use it by running:

```
yarn format
```

[Solhint](https://protofire.github.io/solhint/) is used to lint Solidity files. Run it with:

```
yarn hint
```

[TypeChain](https://github.com/ethereum-ts/Typechain) is used to generates types for Hardhat scripts and tests. Generate them by running:

```
yarn typechain
```
