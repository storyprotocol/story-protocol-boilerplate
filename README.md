## Story Protocol Boilerplate Code

This repository should be used to help developers get started with building on top of Story Protocol. It includes a simple contract used for IP registration of mock ERC-721 NFTs, and an accompanying test.

## Documentation

Find the full smart contract guide here: https://docs.story.foundation/docs/get-started-with-the-smart-contracts

We recommend developers who utilize this guide to build off a fork of this repo as a starting point, as it includes all needed dependencies and tooling.

## Run Tests

Run all the tests: `forge test --fork-url https://testnet.storyrpc.io/`

Run a specific test: `forge test --fork-url https://testnet.storyrpc.io/ --match-path test/IPALicenseTerms.t.sol`
