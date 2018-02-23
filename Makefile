dep:
	mix local.hex --force
	mix local.rebar --force
	mix deps.get

test: dep
	mix credo
	mix format --check-formatted
	mix test
