# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-22

### Added
- **Settings module** (`Exdantic.Settings`) — environment-variable-based configuration loader:
  - `load/2`, `load!/2`, and `from_system_env/2` entry points
  - Field-driven env lookup with `env_prefix` and `env_nested_delimiter`
  - Field-level absolute env override via `extra: %{"env" => "KEY"}`
  - Test-friendly `env: %{}` injection (no process env mutation required)
  - Dedicated error codes: `:env_cast`, `:env_json`, `:env_key_conflict`
  - Nested env decoding with prefix-based matching strategy that correctly handles fields containing underscores in their names
  - Deep-merge of exploded nested values over top-level JSON values
  - Case-insensitive env normalization with collision detection
  - `ignore_empty` option to control whether empty strings are treated as absent
  - `allow_atoms: :existing` option for safe atom env casting
  - Validation that `:input` option is a map
  - Settings submodules: `Decode`, `DeepMerge`, `Env`, `Keys`, `Loader`, `NormalizeKeys`
- **Boolean schema support** in `JsonSchema.Resolver` — `true`/`false` can now be used as definitions and are resolved correctly
  - When merging metadata into a boolean schema, the resolver wraps elements in an `allOf` structure to preserve schema validity
  - Support for both `definitions` and `$defs` in the reference resolver
- **Schema metadata serialization** — fields are now serialized via `:erlang.term_to_binary` during compilation and decoded at runtime, fixing compile-time escaping failures for Regex constraints on newer Elixir/OTP versions
- **Documentation overhaul**:
  - 9 modular numbered guides replacing flat markdown files (`guides/01_overview_and_quickstart.md` through `guides/09_errors_reports_and_operations.md`)
  - Documented `Types.type/1`, `Types.validate/2`, `Types.coerce/2` helpers
  - Documented optional `coerce_rule/0` and `custom_rules/0` callbacks for custom type modules
  - Documented `create_wrapper_factory/2` for reusable wrapper templates
  - Documented `error_format` and `allow_population_by_field_name` configuration fields
  - Settings/env guide (`docJune/SETTINGS_ENV_GUIDE.md`)
  - Strict mode deprecation analysis and JSV compatibility analysis
  - Production error handling guide
- **Project branding** — SVG logo asset (`assets/exdantic.svg`)
- **Examples**:
  - `examples/settings_loader.exs` — comprehensive settings loader example
  - `examples/run_all.sh` — bash script to automate execution of all examples
- **Tests**:
  - `settings_test.exs` — unit tests for the settings loader
  - `settings_property_test.exs` — property-based tests covering precedence, env decoding, nested merge, union behavior, and atom safety
  - Boolean schema resolution tests in `resolver_test.exs`
  - Underscore delimiter tests for nested settings paths

### Changed
- **Settings behavior** (documented and validated by property tests):
  - Precedence: `input > env > defaults`
  - Structured types (arrays, maps, nested schemas) are JSON-only via env
  - Exploded nested values deep-merge over top-level JSON values
  - Conservative union env decoding (no union-level scalar coercion probing)
  - No exploded addressing into arrays in v1
- **RootSchema** refactored to use private functions (`__root_type__/0`) instead of module attributes for storing root types, improving consistency in code generation
- **JsonSchema.Resolver** updated to use maps instead of `MapSet` for tracking visited nodes, improving performance and adding stricter definition checks
- **Runtime module** — constraint keys extracted to a module attribute (`@constraint_keys`) replacing runtime `MapSet` creation; refined type specifications
- **EnhancedValidator** — refined type specifications
- Optimized list emptiness checks across the codebase by replacing `length/1 > 0` with direct empty list comparisons (`!= []`)
- Updated ExDoc configuration with grouped extras for HexDocs navigation
- Updated dependencies in `mix.lock` (including `ex_doc` and `dialyxir`)
- Rewrote `README.md` for better clarity and faster onboarding

### Removed
- `.dialyzer_ignore.exs` — removed after resolving underlying Dialyzer analysis issues
- Legacy flat documentation files: `ADVANCED_FEATURES_GUIDE.md`, `GETTING_STARTED_GUIDE.md`, `LLM_INTEGRATION_GUIDE.md`
- `examples/phase_3_example.exs` (incomplete/broken)

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
