# Elixium Design Specification - Request for Comments
This is the beginnings of a design specification, primarily to be used for development purposes, but will likely also be used as the technical backbone for a whitepaper as well. I'm adding as a Markdown file in order for the community to comment, submit changes, and otherwise discuss.

Most of these initial thoughts came out of an in-person conversation between @alexdovzhanyn and @derekbrown on September 10, 2018.

## Summary

The goal of Elixium is to build a fast (10k+ tx/sec), anonymous (zero-knowledge), scriptable blockchain using Elixir.
Elixium chains will be Proof-of-Work (implementation described below), utilizing the distributed nature of Elixir to minimize the inefficiencies often found in mining.
For additional scalability, Elixium will also be sharded, utilizing a "journal" approach to maintain chain fidelity across shards.

"You can trust yourself." - Alex Dovzhanyn, 2018. Basic premise of trust in Elixium.

## Design & Features

### You Can Trust Yourself.
As a node, you only need to know the entirety of _your_ shard, having verified the chain when you first joined the network. Since then, you download block info from other shards that you're alerted to via crosslinks on the Journal chain (which you keep a copy of), validate the new blocks, discard the block info, and add a record to your local Journal as proof that the chain up to that point has been verified.

### Sharded
The chain is split into multiple fragments, or shards, which allow for dataset scalability. Rather than having each node store a full copy of the entire ledger, the state of all contracts, and the state of transactions, _each node needs only retain data relevant to the shard which it has been assigned_. This alludes to the fact that shards are assigned permanently; once a node has received it's shard assignment, it will store only data related to transactions and contracts that live within that shard. 

If a node wishes to switch to a new shard (for whatever reason) it would be possible to do so by deleting (local) chain data and resetting the node, at which point the node would again randomly be assigned a shard. It is important that nodes are not allowed to choose which shard they want to run on, as this could lead to unbalanced shards, where the number of nodes on a particular shard largely outnumbers the nodes on another shard.

Although each node only stores a subset of the entire chain, **it is mandatory that every node downloads and verifies each and every block on the chain, regardless of whether a given block is on it's shard.** Once a node has verified a block, it can choose to either store or discard it. 

_Side Note: This may lead to "malicious" action by nodes on a shard. A node might choose not to store **any** blocks that it receives after verifying them. Do these nodes get penalized if caught avoiding block storage in order to evade opportunity cost of storage? How does this play with SPV clients?_ 

### P2P Network

The networking mechanism behind Elixium implements a binary zero-knowledge protocol called [Ghost](add link here) (_in active development_), a TCP protocol based on the [SRP 6a](http://srp.stanford.edu/design.html) authentication scheme. Alienated peers will complete an initial registration phase where they interactively establish authentication parameters that will be used in the future. Peers will be able to establish a secure connection with one another _without ever sending a password or shared secret over the wire_. As a result of completing an authentication handshake, the peers each individually derive a shared secret. 

The shared secret is truncated to 32 bytes and is used as an input to the AES 256 bit ECB cipher when encrypting messages. Each message after the authentication is encrypted pre-flight and decrypted post-flight.

**The implementation of zero-knowledge stateful authentication lends itself well to prevention of possible man-in-the-middle attack vectors.**

_Note: A possible way to increase the unlikeliness of a MITM attack even further is to apply a stateful nonce to the key of the AES cipher. For example, adding a nonce to the input key and incrementing it after every message. Then, even if a MITM attack is successful, the attacker would need to know how many messages occurred before they completed the attack._

### Proof of Work
- Elixium will be utilizing the memory-hardened [Itsuku](https://eprint.iacr.org/2017/1168.pdf) instead of the generic Bitcoin implementation.

### Anonymity
- The Elixium Core Wallet automatically performs a key rotation after every transaction, meaning that you are not trackable by public key. Used addresses are not discarded in case a peer sends multiple transactions to the same wallet address.
- By implementing zkSNARKS, we hope to avoid user identification via transaction patterns, addresses, or transaction contents.

### Node Discovery
- Currently using a load-balanced bootstrapping server which keeps a log of IP addresses of all the nodes which have come online.
- _Is there a better way to achieve this without having a central bootstrapping server?_

### Smart Contract & Execution
- WASM compiler.
- Execution architecture TBD. This is a large conversation.

### Speed
- With node response times of roughly 50 microseconds, transaction speeds are 4000x the speed of Bitcoin
- Process roughly 20,000 transactions per second
- _TBD._ Alex & Derek discussed pros & cons of sub-second blocks vs. 2 minute block times. Conversation ended leaning toward faster block times.

## Potential Drawbacks & Challenges

- Scalability needs to be tested with many nodes. A potential drawback is that Elixir itself is not enough to make up for inefficiencies in PoW approach and that this can only be solved _architecturally_.
- At a glance, sharding seems unnecessarily complex. Is it actually necessary?
- Unless we devise a novel way for execution, contracts may not be able to be protected by zero-knowledge. They must self-declare, because Elixium needs to know _prior to execution_ that they have enough "gas" to afford the execution itself.
  - A possible solution would be to have the contract developer commit a set of unspent transaction outputs to the contract, which can not be used for non-contract transactions after being committed. This also lends itself well to solving the developer identification problem shown above; a contract developer need not reveal themselves in order to fund a contract, and better yet _contracts can be publicly fundable (Potentially a huge win for non-profit organizations that may want to accept contract funding as a donation)_.

## Alternative Approaches

- Chains operate on Proof of Stake (a la Ethereum 2.0, others - validators pay to play and randomly selected for validation a la jury duty)
- Chains operate on Proof of Cooperation (a la Faircoin, others - stable centralized and approved nodes)
- No sharding at all, no Journal chain.

## Questions & Topics of Discussion

- Is 1024 the right number of shards? Does it matter?
- How is a new node's initial shard determined? Dice roll?
- How do new nodes perform discovery of other nodes across all necessary shards for chain validation purposes?
- How should we approach and think about block times?
- How should we approach contract execution? Off-chain? On-chain?
- Can we compute costs ahead of time without knowledge of developer? Is developer self-identification required?
