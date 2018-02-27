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
}

UltraDark.charge_gamma = function(max_gamma) {
  return (amount) => {
    if (gamma + amount > max_gamma) {
      throw { error: 'Out of Gamma' , gamma_used: gamma, max_gamma: max_gamma, gamma_attempted: amount}
    } else {
      gamma += amount
    }
  }
}
