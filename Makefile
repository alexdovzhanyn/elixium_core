linter:
	mix credo
	# mix format --check-formatted

testing: linter
	mix test
