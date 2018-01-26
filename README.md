[![Packagist](https://img.shields.io/badge/license-MIT-blue.svg)]()

# UltraDark
UltraDark is a peer-to-peer network and blockchain written in Elixir. It aims to be a privacy focused blockchain that supports contracting. We're looking for
contributors, so pull requests and issues are welcome!

## Why Elixir?
Blockchain technology in it's current state is written mostly in C or C-like languages, leaving development communities outside of this umbrella of languages
lacking in their support for the technology. By writing a blockchain in Elixir we hope to accomplish a few things:

1. Expand the blockchain development community into new languages and provide a reference to those who are more comfortable in Elixir
2. Take advantages of the insane speed of Elixir to allow for a faster peer-to-peer network.
3. Once again taking advantage of the performance of Elixir, allow for the development of decentralized apps within the Elixir community.

This code is licensed under the MIT License, which means _anyone_ can use it to do _anything_ they want.

## Prerequisites
1. Elixir

## Setup
Run `mix deps.get` to fetch any dependencies needed to run UltraDark. After downloading all dependencies, run `mix compile` to compile the Elixir code. Currently,
UltraDark is only under development and is unavailable to be used as a network or currency. In order to play around with UltraDark and it's methods, run `iex -S mix`. This
will pop open an iex session with UltraDark loaded.

Here is a sample of how to start the UltraDark blockchain manually:

```elixir
%{blockchain: [block]} = UltraDark.initialize

#=> %{blockchain: [
#          %{difficulty: 5.0,
#               hash: "79644A8F062F1BA9F7A32AF2242C04711A634D42F0628ADA6B985B3D21296EEA",
#               index: 0,
#               nonce: nil,
#               previous_hash: nil,
#               timestamp: nil,
#               transactions: [
#                 %{inputs: [],
#                     outputs: "GENESIS BLOCK"
#                 }
#              ]
#          }
#     ]}

block |> UltraDark.Blockchain.Block.initialize |> UltraDark.Blockchain.Block.mine

# %{ difficulty: 5.0,
#       hash: "C75616884DCBFA36E0BC1367C1095D9479D61EA372BEB32E046186960233DE70",
#       index: 1,
#       nonce: 0,
#       previous_hash: "79644A8F062F1BA9F7A32AF2242C04711A634D42F0628ADA6B985B3D21296EEA",
#       timestamp: "2018-01-26 02:31:13.926205Z",
#       transactions: [
#         %{inputs: [],
#             outputs: []
#          }
#       ]
#   }
```

## Development

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ultradark](https://hexdocs.pm/ultradark).
