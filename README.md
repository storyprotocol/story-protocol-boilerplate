## Story - Smart Contract Tutorial

This repository should be used to help developers get started with building on top of Story's smart contracts. It includes a simple contract used for IP registration of mock ERC-721 NFTs, and accompanying tests.

## Documentation

Find the full smart contract guide here: https://docs.story.foundation/docs/get-started-with-the-smart-contracts

## Get Started

1. `yarn`

2. Run the tests

    2a. Run all the tests: `forge test --fork-url https://aeneid.storyrpc.io/`

    2b. Run a specific test: `forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/1_LicenseTerms.t.sol`

## Cross Chain Royalty Payments: 6_DebridgeHook.t.sol

This specific test does the following:

1. Constructs a deBridge API call that swaps tokens cross-chain and also includes a `dlnHook`. This hook will execute a certain action once the swap is completed. In this case, it will take the swapped tokens and pay royalties to an IP Asset on Story

2. It will execute the API call, which doesn't actually do anything, but returns a response that includes a payload and an estimate you can use to actually run the transaction on the source swap chain (ex. Ethereum, Solana, etc)

3. Verifies that the API call actually returns the payload and estimate

In a real scenario, you would take the API response and execute the transaction on the source chain.
