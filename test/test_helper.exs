ExUnit.start(timeout: 600000, capture_log: true)



#task = Task.async(fn -> IO.gets("""
#Welcome to the test suite.. Choose what you would like to test:
#0 => Run All Tests
#1 => Block Tests
#2 => Error Tests
#3 => KeyPair Tests
#4 => Node Tests
#5 => Store Tests
#6 => Transaction Tests
#7 => Utilities Tests
#8 => Validator Tests
#""" ) |> String.trim("\n") end)
