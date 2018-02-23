'use strict'

let UltraDark = {}
let gamma  = 0

UltraDark.Contract = class  {
  constructor(opts = {}) {
    this.sanitized_block_index = opts.block_index
    this.sanitized_block_hash = opts.block_hash
    this.sanitized_block_nonce = opts.block_nonce
    this.sanitized_transaction_id = opts.transaction_id
  }

  main() {

  }
}

UltraDark.Contract.charge_gamma = function(amount) {
  gamma += amount
}
