'use strict'

let UltraDark = {}
let gamma  = 0

UltraDark.Contract = class  {
  constructor(opts = {}) {
    this.block_index = opts.block_index
    this.block_hash = opts.block_hash
    this.block_nonce = opts.block_nonce
    this.transaction_id = opts.transaction_id
  }

  main() {

  }
}

UltraDark.Contract.charge_gamma = function(amount) {
  gamma += amount
}
