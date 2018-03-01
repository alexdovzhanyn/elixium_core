class ThisIsAContract extends UltraDark.Contract {
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

    UltraDark.updateChainState({
      somevalue: x,
      othervalue: "boring other value"
    })

    return "The hash is: " + this.block_hash + ", but the transaction id is: " + this.transaction_id
  }

  otherFunction(value) {
    return value + value + value
  }

  reallyExpensiveFunction() {
    let a = 1
    let b = 2
    let c = 3

    a = a + b
    b = a + c
    c = a + b

    return c
  }

  loopingFunction() {
    let arr = []

    for (let i = 0; i < 100; i++) {
      arr.push(i)
    }

    return arr
  }
}
