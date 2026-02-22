# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-22

### Added
- Added `Exdantic.Settings` env-based settings loader with:
  - `load/2`, `load!/2`, and `from_system_env/2`
  - field-driven env lookup with `env_prefix` and `env_nested_delimiter`
  - field-level absolute env override via `extra: %{"env" => "KEY"}`
  - test-friendly `env: %{}` injection (no process env mutation required)
  - loader-level errors: `:env_cast`, `:env_json`, `:env_key_conflict`

### Changed
- Settings decoding and merge behavior now documented and validated by property tests:
  - precedence: `input > env > defaults`
  - structured types are JSON-only
  - exploded nested values deep-merge over top-level JSON values
  - conservative union env decoding (no union-level scalar coercion probing)
  - no exploded addressing into arrays in v1

## [0.0.2] - 2025-01-05

### Changed
- Updated CI workflow files to show proper error output

## [0.0.1] - 2025-01-05

Initial release of Exdantic, a powerful schema definition and validation library for Elixir, based on the original [Elixact](https://github.com/LiboShen/elixact) project by LiboShen.

### Added
- Core schema definition and validation functionality
- Support for basic types: string, integer, float, boolean, atom, any, map
- Support for complex types: arrays, maps with typed keys/values, unions, tuples
- Compile-time schema definition with `use Exdantic`
- Runtime schema creation with `Exdantic.Runtime`
- Model validators for cross-field validation
- Computed fields for deriving additional fields from validated data
- TypeAdapter for schemaless validation
- Wrapper models for single-field validation
- RootSchema for non-dictionary validation
- Comprehensive constraint system for all types
- Custom type support
- Struct generation with `define_struct: true`
- Enhanced JSON Schema generation with LLM provider optimization
- DSPy integration patterns
- Configuration system with presets and builder pattern
- Path-aware error messages
- Type coercion with configurable strategies
- Extensive test coverage
- Documentation and examples

[Unreleased]: https://github.com/nshkrdotcom/exdantic/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/nshkrdotcom/exdantic/compare/v0.0.2...v0.1.0
[0.0.2]: https://github.com/nshkrdotcom/exdantic/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/nshkrdotcom/exdantic/releases/tag/v0.0.1
