## Multi Signature Wallet Contract

This smart contract demonstrated a multi signature wallet written in solidity
and tested using the *foundry framework*.

## Features
- The contract allows multiple owners to collectively control the funds in the wallet.
- Each owner is a unique address with his own private key.
- A specified number of approvals are required to execute transactions.
- Only owners can submit, approve and cancel non-executed transactions.
- If an approved contract gets cancelled by all approvers, i.e. it has 0 approvals, it is removed from the contract.

### About the Contract
The MultiSignatureWallet contract comprises to predefined owners (while deploying) who collectively control the flow of funds through the contract using a number game i.e. a predefined approval number required for executing the contract. Only the owners have the right to submit, approve or cancel their approval for the contract.  <br>
Owners cannot re-approve a transaction, they can only cancel their approval in this case. Similarly, owners cannot execute a transaction until it has received the required number of approvals. One thing I have added on is when a owner cancels his approval and say if at the same time, the approvals for that specific transaction get to 0, the transaction is automatically removed from the transactions buffer as well as any amount transferred to the contract is reverted back to the submitter because this felt natural as if all owners have revoked their approvals, which means they don't want this transaction to proceed at all. 


## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/DeployMultiSingatureWallet.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Documentation

https://book.getfoundry.sh/
