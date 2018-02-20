class MyContract extends UltraDark.Contract {
  constructor(opts) {
    super(opts)
  }

  main() {
    let x = 5
    this.otherFunction("hello")

    if (1 + 1 == 2) {
      x += 5
    } else {
      x -= 2
    }

    return "The hash is: " + this.block_hash
  }

  otherFunction(value) {
    return value + value + value
  }
}
