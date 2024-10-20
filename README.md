# Spark ALM Controller

![Foundry CI](https://github.com/marsfoundation/spark-alm-controller/actions/workflows/ci.yml/badge.svg)
[![Foundry][foundry-badge]][foundry]
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/marsfoundation/spark-alm-controller/blob/master/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

This repo contains the onchain components of the Spark Liquidity Layer. The following contracts are contained in this repository:

- `ALMProxy`: The proxy contract that holds custody of all funds. This contract routes calls to external contracts according to logic within a specified `controller` contract. This pattern was used to allow for future iterations in logic, as a new controller can be onboarded and can route calls through the proxy with new logic. This contract is stateless except for the ACL logic contained within the inherited OpenZeppelin `AccessControl` contract.
- `ForeignController`: This controller contract is intended to be used on "foreign" domains. The term "foreign" is used to describe a domain that is not the Ethereum mainnet.
- `MainnetController`: This controller contract is intended to be used on the Ethereum mainnet.
- `RateLimits`: This contract is used to enforce and update rate limits on logic in the `ForeignController` and `MainnetController` contracts. This contract is stateful and is used to store the rate limit data.

## Architecture

The general structure of calls is shown in the diagram below. The `controller` contract is the entry point for all calls. The `controller` contract checks the rate limits if necessary and executes the relevant logic. The `controller` can perform multiple calls to the `ALMProxy` contract atomically with specified calldata.

<p align="center">
  <img src="https://github.com/user-attachments/assets/832db958-14e6-482f-9dbc-b10e672029f7" alt="Image 1" height="700px" style="margin-right:100px;"/>
</p>

The diagram below provides and example of calling to mint USDS using the Sky allocation system. Note that the funds are always held custody in the `ALMProxy` as a result of the calls made.

<p align="center">
  <img src="https://github.com/user-attachments/assets/312634c3-0c3e-4f5a-b673-b44e07d3fb56" alt="Image 2" height="700px"/>
</p>

## Permissions

All contracts in this repo inherit and implement the AccessControl contract from OpenZeppelin to manage permissions. The following roles are defined:
- `DEFAULT_ADMIN_ROLE`: The admin role is the role that can grant and revoke roles. Also used for general admin functions in all contracts.
- `RELAYER`: Used for the ALM Planner offchain system. This address can call functions on `controller` contracts to perform actions on behalf of the `ALMProxy` contract.
- `FREEZER`: Allows an address with this role to freeze all actions on the `controller` contracts. This role is intended to be used in emergency situations.
- `CONTROLLER`: Used for the `ALMProxy` contract. Only contracts with this role can call the `call` functions on the `ALMProxy` contract. Also used in the RateLimits contract, only this role can update rate limits.

## Controller Functionality
All functions below change the balance of funds in the ALMProxy contract and are only callable by the `RELAYER` role.

- `ForeignController`: This contract currently implements logic to:
  - Deposit and withdraw on EVM compliant L2 PSM3 contracts (see [spark-psm](https://github.com/marsfoundation/spark-psm) for implementation).
  - Initiate a transfer of USDC to other domains using CCTP.
- `MainnetController`: This contract currently implements logic to:
  - Mint and burn USDS on Ethereum mainnet.
  - Deposit, withdraw, redeem in the sUSDS contract.
  - Swap USDS to USDC and vice versa using the mainnet PSM.
  - Transfer USDC to other domains using CCTP.

## Rate Limits

The `RateLimits` contract is used to enforce rate limits on the `controller` contracts. The rate limits are defined using `keccak256` hashes to identify which function to apply the rate limit to. This was done to allow flexibility in future function signatures for the same desired high-level functionality. The rate limits are stored in a mapping with the `keccak256` hash as the key and a struct containing the rate limit data:
- `maxAmount`: Maximum allowed amount at any time.
- `slope`: The slope of the rate limit, used to calculate the new limit based on time passed. [tokens / second]
- `lastAmount`: The amount left available at the last update.
- `lastUpdated`: The timestamp when the rate limit was last updated.

The rate limit is calculated as follows:

<div align="center">

`currentRateLimit = min(slope * (block.timestamp - lastUpdated) + lastAmount, maxAmount)`

</div>

This is a linear rate limit that increases over time with a maximum limit. This rate limit is derived from these values which can be set by and admin OR updated by the `CONTROLLER` role. The `CONTROLLER` updates these values to increase/decrease the rate limit based on the functionality within the contract (e.g., decrease the rate limit after minting USDS by the minted amount by decrementing `lastAmount` and setting `lastUpdated` to `block.timestamp`).

## Testing

To run all tests, run the following command:

```bash
forge test
```

In order to get the mainnet deployment testing to work, the staging environment must be deployed against local forks of mainnet and base until the staging deployment is live. Use the following procedure to run the setup:

1. Set up two local forks of mainnet and base using the following commands in different terminal windows:

```
anvil --fork-url $MAINNET_RPC_URL
```
```
anvil --fork-url $BASE_RPC_URL -p "8546"
```

2. Set the environment variables for the mainnet and base RPC URLs to the new forks in the terminal that will run the testing:
```
export MAINNET_RPC_URL="http://127.0.0.1:8545"
export BASE_RPC_URL="http://127.0.0.1:8546"
```

3. Run the following commands to impersonate accounts and send funds to the contracts for testing. These commands do the following:
   - Set the balance of the `ETH_FROM` address to 1000 ETH.
   - Send mainnet USDS to `ETH_FROM` from the `0x3E67e3e55F0E26d0C566910B51347e04222E808e` address (mainnet whale).
   - Send mainnet DAI to `ETH_FROM` from the `0xD1668fB5F690C59Ab4B0CAbAd0f8C1617895052B` address (mainnet whale).
```
cast rpc --rpc-url="$MAINNET_RPC_URL" anvil_setBalance $ETH_FROM `cast to-wei 1000 | cast to-hex`
cast rpc --rpc-url="$MAINNET_RPC_URL" anvil_impersonateAccount 0x3E67e3e55F0E26d0C566910B51347e04222E808e
cast send 0xdC035D45d973E3EC169d2276DDab16f1e407384F 'transfer(address,uint256)' $ETH_FROM 100000000000000000000000 --unlocked --from 0x3E67e3e55F0E26d0C566910B51347e04222E808e
cast rpc --rpc-url="$MAINNET_RPC_URL" anvil_impersonateAccount 0xD1668fB5F690C59Ab4B0CAbAd0f8C1617895052B
cast send 0x6b175474e89094c44da98b954eedeac495271d0f 'transfer(address,uint256)' $ETH_FROM 100000000000000000000000 --unlocked --from 0xD1668fB5F690C59Ab4B0CAbAd0f8C1617895052B
```

4. Run the following command to deploy the staging environment against both local forks:
```
make deploy-ethereum-staging
```

5. Copy the files `mainnet-latest.json` and `base-latest.json` from the `script/output/1/` directory to `mainnet-20241017.json` and `base-20241017.json` in the `script/output/1` directory respectively.
6. Run `forge t --mc DeployEthereumTest -vvv` to run the staging environment tests in isolation, or run all tests with `forge test`.


***
*The IP in this repository was assigned to Mars SPC Limited in respect of the MarsOne SP*

<p align="center">
  <img src="https://1827921443-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FjvdfbhgN5UCpMtP1l8r5%2Fuploads%2Fgit-blob-c029bb6c918f8c042400dbcef7102c4e5c1caf38%2Flogomark%20colour.svg?alt=media" height="150" />
</p>
