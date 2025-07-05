Usage
To run the complete test suite:
bash# Run all tests
mix test

# Run specific test files
mix test test/exdantic/runtime_test.exs
mix test test/exdantic/type_adapter_test.exs
mix test test/exdantic/integration_test.exs

# Run with coverage
mix test --cover

# Run performance tests
mix test --include slow

# Run integration tests
mix test --include integration

