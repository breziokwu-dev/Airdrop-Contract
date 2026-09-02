# Merkle Airdrop

A gas-efficient ERC-20 token airdrop system that uses a **Merkle tree** to verify user allocations without storing every allocation on-chain.

> **Status:** 🚧 In Development

## Overview

Traditional airdrop implementations can become expensive when every eligible user's allocation is stored directly on-chain.

This project uses a **Merkle tree** to move the large allocation dataset off-chain while storing only a single **Merkle root** on-chain.

Users claim their allocation by providing:

* Their token allocation
* A Merkle proof

The `MerkleAirdrop` contract reconstructs the Merkle root from the supplied proof and verifies that the caller is genuinely included in the committed allocation dataset.

### High-Level Flow

```text
              OFF-CHAIN
┌─────────────────────────────────────┐
│        Allocation Dataset           │
│              ↓                      │
│        Merkle Tree Generator        │
│              ↓                      │
│     Merkle Root + Merkle Proofs     │
└──────────────────┬──────────────────┘
                   │
                   │ Merkle Root
                   ▼
              ON-CHAIN
┌─────────────────────────────────────┐
│          MerkleAirdrop               │
│                                     │
│  Immutable Merkle Root              │
│  Immutable ERC-20 Token             │
│  Claim Tracking                     │
│  Merkle Proof Verification          │
│  Token Distribution                 │
└──────────────────┬──────────────────┘
                   │
                   ▼
                 User
```

## Why Merkle Trees?

An on-chain mapping such as:

```solidity
mapping(address => uint256) allocation;
```

can retrieve an individual user's allocation efficiently, but populating the mapping for a large number of users requires many expensive on-chain storage writes.

A Merkle tree instead allows the allocation dataset to remain off-chain while the contract stores only one 32-byte Merkle root.

For a claim, the user provides a Merkle proof that allows the contract to verify:

```text
(address, allocation)
        ↓
      Leaf
        ↓
   Merkle Proof
        ↓
Reconstructed Root
        ↓
  Stored Root?
```

This provides a compact cryptographic commitment to the entire allocation dataset.

## Core Contracts

### `MerkleAirdrop.sol`

The main airdrop contract.

Responsibilities:

* Store the ERC-20 airdrop token
* Store the immutable Merkle root
* Track whether an address has claimed
* Verify Merkle proofs
* Check claim eligibility
* Distribute tokens
* Enforce the airdrop expiration
* Allow authorized withdrawal of remaining tokens after expiration
* Emit claim events

### `MockERC20.sol`

A simple ERC-20 token used for development and testing.

Responsibilities:

* Provide a token for the airdrop
* Allow test tokens to be minted
* Fund the `MerkleAirdrop` contract during testing

The mock token remains separate from the airdrop logic.

## Merkle Leaf Design

For this version of the project, each Merkle leaf is constructed from the user's address and allocation:

```text
leaf = keccak256(abi.encode(address, amount))
```

No index is included in the leaf.

For example:

```text
Alice + 100 AIR
       ↓
keccak256(...)
       ↓
Merkle Leaf
```

The off-chain Merkle tree generator and the Solidity contract must use the exact same encoding and hashing conventions.

The tree uses sorted-pair hashing to remain compatible with the Merkle proof verification implementation.

## Claim Flow

A user calls:

```solidity
claim(uint256 amount, bytes32[] calldata merkleProof)
```

The contract performs the following steps:

1. Check that `msg.sender` has not already claimed.
2. Construct the Merkle leaf from `msg.sender` and `amount`.
3. Verify the Merkle proof against the stored Merkle root.
4. Check that the airdrop contract has sufficient token balance.
5. Mark the caller as claimed.
6. Transfer the allocation to the caller.
7. Emit the `Claimed` event.

Conceptually:

```text
User
 │
 │ claim(amount, proof)
 ▼
Check already claimed
 │
 ▼
Construct leaf
 │
 ▼
Verify Merkle proof
 │
 ▼
Check token balance
 │
 ▼
Mark as claimed
 │
 ▼
Transfer tokens
 │
 ▼
Emit Claimed event
```

The claimant's address is derived from `msg.sender` rather than supplied as a function argument. This prevents a caller from simply specifying another user's address.

## State

The core contract state consists of:

```solidity
IERC20 public immutable airdropToken;
bytes32 public immutable merkleRoot;
uint256 public immutable expiration;

mapping(address => bool) public hasClaimed;
```

### Immutability

The following values cannot be changed after deployment:

* Airdrop token
* Merkle root
* Expiration timestamp

The immutable Merkle root provides a fixed commitment to the original allocation dataset.

There is no root-update mechanism in V1.

## Events

Successful claims emit:

```solidity
event Claimed(address indexed account, uint256 amount);
```

This provides an on-chain record that can be consumed by off-chain applications and monitoring systems.

## Custom Errors

The contract will use custom errors instead of revert strings for common failure conditions.

Expected errors include cases such as:

```text
AlreadyClaimed
InvalidProof
AirdropExpired
InsufficientBalance
Unauthorized
```

The exact interface will be finalized during implementation.

## Airdrop Lifecycle

The airdrop follows a simple lifecycle:

```text
DEPLOYED
    ↓
FUNDED
    ↓
ACTIVE
    ↓
EXPIRED
```

### Funding

The `MerkleAirdrop` contract does not require a dedicated funding function.

The ERC-20 tokens can simply be transferred to the deployed airdrop contract.

```text
MockERC20
    │
    │ transfer()
    ▼
MerkleAirdrop
    │
    │ claim()
    ▼
User
```

### Expiration

Claims are allowed while the airdrop is active.

After the expiration timestamp:

```text
claim() → revert
```

The authorized account can then withdraw the remaining airdrop tokens.

The administrator cannot withdraw the airdrop tokens while legitimate claims are still active.

## Access Control

The administrator has limited authority.

The administrator **cannot**:

* Change the Merkle root
* Change the token
* Change user allocations
* Mark users as claimed
* Modify individual claims

Administrative authority is primarily concerned with recovering remaining tokens after the airdrop expires.

## Security Considerations

The project is designed around several important security properties:

### No Double Claims

Once an address successfully claims:

```solidity
hasClaimed[msg.sender] = true;
```

A second claim is rejected.

### Invalid Proofs

A user cannot claim an arbitrary amount.

The proof must demonstrate that:

```text
(msg.sender, amount)
```

is part of the allocation committed by the stored Merkle root.

### Caller Identity

The contract uses:

```solidity
msg.sender
```

when constructing the leaf.

This prevents users from submitting another address as the beneficiary.

### Checks-Effects-Interactions

The claim flow follows the general pattern:

```text
Checks
  ↓
State Effect
  ↓
External Interaction
  ↓
Event
```

Token transfers will use OpenZeppelin's safe ERC-20 transfer abstraction.

## Testing Strategy

Testing will go beyond basic happy-path tests.

### Unit Tests

Tests will cover:

* Deployment
* Constructor parameters
* Valid claims
* Invalid proofs
* Incorrect allocations
* Double claims
* Token transfers
* Insufficient token balance
* Expiration
* Withdrawal
* Access control
* Event emission

### Fuzz Tests

Foundry fuzzing will be used to test the contract against a wide range of inputs, particularly:

* Arbitrary amounts
* Addresses
* Invalid proofs
* Claim state transitions

### Invariant Tests

Invariant testing will verify system-level properties that must remain true regardless of the sequence of interactions.

Examples include:

* A successfully claimed address cannot claim again.
* Invalid Merkle proofs cannot result in successful claims.
* Claims cannot occur after expiration.
* The contract cannot distribute more tokens than are actually available.
* Claim accounting remains consistent with successful claims.

### Integration Tests

Because the project has both an off-chain and on-chain component, integration testing will verify that:

```text
Allocation Dataset
        ↓
Merkle Generator
        ↓
Generated Root + Proof
        ↓
Solidity Contract
        ↓
Successful Verification
```

The off-chain Merkle implementation must produce roots and proofs compatible with the Solidity verifier.

## Project Structure

The planned repository structure is:

```text
Airdrop-Contract/
│
├── src/
│   ├── MerkleAirdrop.sol
│   └── MockERC20.sol
│
├── test/
│   ├── MerkleAirdropTest.t.sol
│   ├── MerkleAirdropFuzzTest.t.sol
│   └── MerkleAirdropInvariantTest.t.sol
│
├── script/
│   ├── Deploy.s.sol
│   ├── FundAirdrop.s.sol
│   ├── Claim.s.sol
│   └── WithdrawRemaining.s.sol
│
├── offchain/
│   ├── allocations.json
│   ├── generateMerkle.ts
│   └── output/
│       └── proofs/
│
├── lib/
├── foundry.toml
└── README.md
```

The structure may evolve as implementation progresses.

## Technology Stack

* **Solidity**
* **Foundry**

  * Forge
  * Cast
  * Anvil
* **OpenZeppelin Contracts**
* **TypeScript/JavaScript** for off-chain Merkle generation
* **Git & GitHub**

## V1 Scope

The first version intentionally keeps the protocol focused.

### Included

* ERC-20 token distribution
* Merkle-tree-based allocation verification
* Immutable Merkle root
* One claim per address
* Claim expiration
* Remaining-token withdrawal
* Custom errors
* Events
* Unit testing
* Fuzz testing
* Invariant testing
* Off-chain Merkle generation
* Deployment and interaction scripts

### Not Included

V1 does not include:

* Upgradeable contracts
* Governance
* DAOs
* Multiple simultaneous airdrops
* Multiple airdrop tokens
* Cross-chain claims
* Token vesting
* Staking
* Signature-based claiming
* Frontend

These may be explored in later projects or future versions.

## Development Roadmap

```text
[ ] Initialize Foundry project
[ ] Define contract interfaces
[ ] Implement MockERC20
[ ] Implement MerkleAirdrop
[ ] Implement Merkle verification
[ ] Implement claim mechanism
[ ] Implement expiration
[ ] Implement remaining-token withdrawal
[ ] Build unit tests
[ ] Add fuzz tests
[ ] Add invariant tests
[ ] Build off-chain Merkle generator
[ ] Verify off-chain/on-chain compatibility
[ ] Write deployment scripts
[ ] Write interaction scripts
[ ] Deploy locally
[ ] Perform end-to-end testing
[ ] Document security assumptions
[ ] Final review
```

## Learning Objectives

This project is intended to provide practical experience with:

* Merkle trees and Merkle proofs
* Cryptographic commitments
* Gas-efficient on-chain data design
* ERC-20 token interactions
* Solidity custom errors and events
* Immutable contract state
* Access control
* Checks-effects-interactions
* Safe ERC-20 interactions
* Foundry unit testing
* Fuzz testing
* Invariant testing
* Off-chain/on-chain interoperability
* Solidity deployment scripts
* Protocol architecture and security reasoning

## License

This project is currently intended for educational and experimental purposes.

```shell
$ forge --help
$ anvil --help
$ cast --help
```
# Airdrop-Contract
