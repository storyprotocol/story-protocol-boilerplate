## Story - Smart Contract Tutorial

This repository should be used to help developers get started with building on top of Story's smart contracts. It includes a simple contract used for IP registration of mock ERC-721 NFTs, and accompanying tests.

## Documentation

Find the full smart contract guide here: https://docs.story.foundation/docs/get-started-with-the-smart-contracts

## Get Started

1. `yarn`

2. Run the tests

    2a. Run all the tests: `forge test --fork-url https://testnet.storyrpc.io/`

    2b. Run a specific test: `forge test --fork-url https://testnet.storyrpc.io/ --match-path test/IPALicenseTerms.t.sol`
