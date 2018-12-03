[![Packagist](https://img.shields.io/badge/license-MIT-blue.svg)]()
[![Build Status](https://travis-ci.org/ElixiumNetwork/elixium_core.svg?branch=master)](https://travis-ci.org/ElixiumNetwork/elixium_core)
[![Join the chat](https://patrolavia.github.io/telegram-badge/chat.png)](https://t.me/elixiumnetwork)

# Elixium
Elixium is a decentralized application network built for developers; its a
Proof of Work blockchain that allows engineers to write programs that run on the
chain. Right now, we're very early in our development phase, so it's a great
time to get involved if you want to sway the direction of the project. We're
completely open source and community driven, and we aim to continue being that
way -- decentralized even within the development team. Check out the
[Contribution Guide](https://github.com/ElixiumNetwork/elixium_core/blob/master/CONTRIBUTING.md)
to get started with contributing to Elixium. If you have any trouble getting set
up or just want to join in with our development discussion, join our
[Telegram Group](https://t.me/joinchat/JjYPS0WI62EMuMXovyjskA). The
[Elixium Development Wiki](https://github.com/ElixiumNetwork/elixium_core/wiki)
is a great place to get familiarized with Elixium's codebase.

### What we're aiming to solve
One of the biggest issues in the blockchain ecosystem right now is the high barrier
to entry for engineers who want to use the technology, whether its to create a
decentralized application or just to interface with the blockchain. This can be
attributed to many different things, but the most pressing reason is that
language support in the ecosystem is very poor. In order for an engineer to
create a decentralized application or smart contract, they need to either learn
a language that is specifically created for smart contracting or use a
predetermined language that they might not already know. The fact of the matter
is that learning a new language can take days or even weeks, and engineers are
very excited about blockchain but don't want to invest weeks of their time
learning a new toolset for a system that might not exist in a few years
(e.g. learning Solidity to create Ethereum dApps), since the ecosystem is so
rapidly evolving.

Elixium mitigates this barrier to entry by employing language agnostic smart
contracts -- decentralized applications that can be written in potentially any
language. Engineers will no longer be tied down to learning a new language like
Solidity or migrating to a language like Javascript, they'll be able to use their
existing toolset and create decentralized applications with any language that
compiles to WebAssembly. They'll be able to use their C, C++, Python, Go, and
any other language they're already familiar with -- all they have to do is learn
a new API to interact with the chain.

### A few other goodies
- Smooth token emission similar to the CryptoNote token emission algorithm
- Memory-hardened PoW algorithm that discourages the usage of FPGA/ASICs
- Journalized sharding (more info [here](https://research.elixium.app/qKN0VINqS_eo3AjJ0O4LLQ#Sharding))
- TCP-layer zero knowledge peer authentication for secure communication
- Low target block solve time

### Anonymous transactions
We're going to be the first (that we're aware of) blockchain that strictly
enforces zkSNARKS technology in it's core. Other networks default to insecure /
non-anonymous transactions and some allow nodes to opt into secure transactions.
Our approach is to only allow anonymous transactions via zero knowledge proofs
-- it's part of our consensus mechanism. We're still researching this, but we're
looking at using Hyrax, a zero knowledge protocol that doesn't need a trusted
setup.

## Why Elixir?
Elixir is a language built with Erlang, and Erlang powers the entire telecom
industry. This is the language that supports the infrastructure of our mobile
phone networks. It was built by a company called Ericcson in 1986 for the
purposes of being distributed, fault tolerant, and to have support for
uninterruptable applications. Erlang was reported to have been used in
production systems with an uptime of 9 nines, which is a maximum downtime of
_32 milliseconds per year_. This is a great fit for blockchain, as it is a system
that needs to be extremely fault tolerant and available.

Concurrency is at the core of the language - processes are cheap and you can
run hundreds of thousands to even millions of processes easily. This allows for
huge performance improvements and parallelization. Erlang has built in error
containment and fault tolerance. It has a really cool feature called a
Supervisor, which automatically restarts failed processes. Erlang also features
hot code swapping functionality -- allowing the software to be updated without
interrupting the program. This makes writing distributed applications easy.

Because of Erlang's large support for concurrency, Elixium is able to mitigate
pain points in blockchain by massively parallelizing things like transaction
processing. Whenever a new transaction comes in, it's cheap and easy to spin up
a separate process to validate and relay that transaction.

Using hot code swapping, Elixium reduces friction from nodes whenever a new
version is released. Rather than a maintainer of a node needing to take down that
node, download a patch, run the update, and then start the node back up,
maintainers can choose to have their nodes updated on the fly. This reduces the
chances of forks happening on the chain whenever a new patch is released.

As a result of the fault tolerance built into Erlang, and by extension Elixir,
Elixium is able to have self-healing nodes. If a node encounters an error during
runtime, rather than crashing and waiting for the maintainer of the node to notice
and restart the node, it is able to restart itself and not lose context of its
current operations, which adds to the total uptime and security of the overall
network.

Blockchain technology in it's current state is written mostly in C or C-like
languages, leaving development communities outside of this umbrella of languages
lacking in their support for the technology. By writing a blockchain in Elixir
we hope to accomplish a few things:

1. Expand the blockchain development community into new languages and provide a reference to those who are more comfortable in Elixir
2. Take advantages of the insane speed of Elixir to allow for a faster peer-to-peer network.
3. Once again taking advantage of the performance of Elixir, allow for the development of decentralized apps within the Elixir community.

This code is licensed under the MIT License, which means _anyone_ can use it to
do _anything_ they want.

### Developer Setup
This is the core repo for the Elixium blockchain. Elixium is split up into a few
different repositories based on their functionality, as follows:
- Elixium Core (this repository)
  A library housing all of the implementation functions and algorithms of Elixium
- [Elixium Miner](https://www.github.com/ElixiumNetwork/elixium_miner)
  Pulls in the core library as a dependency and uses functionality in the core to
  facilitate peer-to-peer connections, block/transaction validation, and mining.
- [Elixium Node](https://www.github.com/ElixiumNetwork/elixium_node)
  Almost exactly the same as the miner except that no mining happens. Miner and
  node are separate for now but are very likely to become one project because of
  all of their similarities.
- [Elixium Wallet](https://www.github.com/ElixiumNetwork/elixium_wallet)
  Aims to be an SPV implementation as a desktop wallet. Is currently only a CLI
  as the main focus is currently on developing the core and network.

Because Elixium Core is a library that other projects in the Elixium ecosystem
pull in as a dependency, the easiest way to update / test the core is by pulling
down either the miner repo or the node repo and using them to call functions
defined in the core. Check the
[Developer Setup Guide](https://github.com/ElixiumNetwork/elixium_core/wiki/Developer-Setup-Guide)
for detailed step-by-step instructions on how to do this.

Documentation for core can be found both in the codebase itself and on
[Hexdocs](https://hexdocs.pm/elixium_core/api-reference.html).

If you want to interact with strictly with core, it's possible (although much
more tedious) by using the test suite or the Elixir interactive shell. To do this,
run `mix deps.get` to fetch any dependencies needed to run Elixium. After
downloading all dependencies, run `mix compile` to compile the Elixir code. To
run the test suite, run `mix test`. In order to play around with Elixium and
it's methods in an interactive shell, run `iex -S mix`.
