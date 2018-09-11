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

### Proof of Work
- Elixium will be utilizing the memory-hardened [Itsuku](https://eprint.iacr.org/2017/1168.pdf) instead of the generic Bitcoin implementation.

### Anonymity
- The Elixium Core Wallet automatically performs a key rotation every 720 blocks (roughly 24 hours) or whenever you receive a transaction, meaning that you are not trackable by public key
- By implementing zkSNARKS, we hope to avoid user identification via transaction patterns, addresses, or transaction contents.

### Node Discovery
- _TBD._

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
- Unless we devise a novel way for execution, contracts may not be able to be protected by zero-knowledge. They must self-declare, because Elixium needs to know _prior to execution_ that they have enough gas to afford the execution itself.

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