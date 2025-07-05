defmodule Exdantic.ConfigTest do
  use ExUnit.Case, async: true

  alias Exdantic.Config

  describe "create/1" do
    test "creates config with default values" do
      config = Config.create()

      assert config.strict == false
      assert config.extra == :allow
      assert config.coercion == :safe
      assert config.frozen == false
      assert config.validate_assignment == false
      assert config.case_sensitive == true
      assert config.error_format == :detailed
      assert config.max_anyof_union_len == 5
    end

    test "creates config with custom options from keyword list" do
      opts = [
        strict: true,
        extra: :forbid,
        coercion: :aggressive,
        error_format: :simple
      ]

      config = Config.create(opts)

      assert config.strict == true
      assert config.extra == :forbid
      assert config.coercion == :aggressive
      assert config.error_format == :simple
      # Default values preserved
      assert config.frozen == false
    end

    test "creates config with custom options from map" do
      opts = %{
        strict: true,
        frozen: true,
        validate_assignment: true
      }

      config = Config.create(opts)

      assert config.strict == true
      assert config.frozen == true
      assert config.validate_assignment == true
    end

    test "raises on invalid configuration options" do
      assert_raise ArgumentError, fn ->
        Config.create(invalid_option: :value)
      end
    end
  end

  describe "merge/2" do
    test "merges configs preserving base values" do
      base = Config.create(strict: false, extra: :allow)
      overrides = %{coercion: :none, error_format: :minimal}

      merged = Config.merge(base, overrides)

      # Base values preserved
      assert merged.strict == false
      assert merged.extra == :allow
      # Override values applied
      assert merged.coercion == :none
      assert merged.error_format == :minimal
    end

    test "merges configs overriding specified values" do
      base = Config.create(strict: false, extra: :allow, coercion: :safe)
      overrides = [strict: true, extra: :forbid]

      merged = Config.merge(base, overrides)

      assert merged.strict == true
      assert merged.extra == :forbid
      # Unchanged values preserved
      assert merged.coercion == :safe
    end

    test "prevents modification of frozen config" do
      frozen_config = Config.create(frozen: true)
      overrides = %{strict: true}

      assert_raise RuntimeError, "Cannot modify frozen configuration", fn ->
        Config.merge(frozen_config, overrides)
      end
    end

    test "allows merging empty overrides with frozen config" do
      frozen_config = Config.create(frozen: true, strict: true)

      # Empty overrides should work even with frozen config
      merged = Config.merge(frozen_config, %{})
      assert merged == frozen_config

      merged = Config.merge(frozen_config, [])
      assert merged == frozen_config
    end
  end

  describe "preset/1" do
    test "creates strict preset configuration" do
      config = Config.preset(:strict)

      assert config.strict == true
      assert config.extra == :forbid
      assert config.coercion == :none
      assert config.validate_assignment == true
      assert config.case_sensitive == true
      assert config.error_format == :detailed
    end

    test "creates lenient preset configuration" do
      config = Config.preset(:lenient)

      assert config.strict == false
      assert config.extra == :allow
      assert config.coercion == :safe
      assert config.validate_assignment == false
      assert config.case_sensitive == false
      assert config.error_format == :simple
    end

    test "creates API preset configuration" do
      config = Config.preset(:api)

      assert config.strict == true
      assert config.extra == :forbid
      assert config.coercion == :safe
      assert config.validate_assignment == true
      assert config.case_sensitive == true
      assert config.error_format == :detailed
      assert config.frozen == true
    end

    test "creates JSON schema preset configuration" do
      config = Config.preset(:json_schema)

      assert config.strict == false
      assert config.extra == :allow
      assert config.coercion == :none
      assert config.use_enum_values == true
      assert config.error_format == :minimal
      assert config.max_anyof_union_len == 3
    end

    test "creates development preset configuration" do
      config = Config.preset(:development)

      assert config.strict == false
      assert config.extra == :allow
      assert config.coercion == :aggressive
      assert config.validate_assignment == false
      assert config.case_sensitive == false
      assert config.error_format == :detailed
    end

    test "creates production preset configuration" do
      config = Config.preset(:production)

      assert config.strict == true
      assert config.extra == :forbid
      assert config.coercion == :safe
      assert config.validate_assignment == true
      assert config.case_sensitive == true
      assert config.error_format == :simple
      assert config.frozen == true
    end

    test "raises on unknown preset" do
      assert_raise ArgumentError, "Unknown preset: :unknown", fn ->
        Config.preset(:unknown)
      end
    end
  end

  describe "validate_config/1" do
    test "validates valid configuration" do
      config = Config.create(strict: true, extra: :forbid)

      assert :ok = Config.validate_config(config)
    end

    test "detects conflict between strict mode and extra allow" do
      config = Config.create(strict: true, extra: :allow)

      assert {:error, ["strict mode conflicts with extra: :allow"]} =
               Config.validate_config(config)
    end

    test "detects conflict between aggressive coercion and validate assignment" do
      config = Config.create(coercion: :aggressive, validate_assignment: true)

      assert {:error, ["aggressive coercion conflicts with validate_assignment"]} =
               Config.validate_config(config)
    end

    test "validates max_anyof_union_len constraint" do
      config = Config.create(max_anyof_union_len: 0)

      assert {:error, ["max_anyof_union_len must be at least 1"]} = Config.validate_config(config)
    end

    test "reports multiple validation errors" do
      config =
        Config.create(
          strict: true,
          extra: :allow,
          coercion: :aggressive,
          validate_assignment: true,
          max_anyof_union_len: 0
        )

      assert {:error, errors} = Config.validate_config(config)
      assert length(errors) == 3
      assert "strict mode conflicts with extra: :allow" in errors
      assert "aggressive coercion conflicts with validate_assignment" in errors
      assert "max_anyof_union_len must be at least 1" in errors
    end
  end

  describe "conversion functions" do
    test "to_validation_opts converts config to validation options" do
      config =
        Config.create(
          strict: true,
          coercion: :safe,
          extra: :forbid,
          validate_assignment: true,
          case_sensitive: false,
          error_format: :simple
        )

      opts = Config.to_validation_opts(config)

      assert opts[:strict] == true
      assert opts[:coerce] == true
      assert opts[:coercion_strategy] == :safe
      assert opts[:extra] == :forbid
      assert opts[:validate_assignment] == true
      assert opts[:case_sensitive] == false
      assert opts[:error_format] == :simple
    end

    test "to_validation_opts handles no coercion" do
      config = Config.create(coercion: :none)
      opts = Config.to_validation_opts(config)

      assert opts[:coerce] == false
      assert opts[:coercion_strategy] == :none
    end

    test "to_json_schema_opts converts config to JSON schema options" do
      config =
        Config.create(
          strict: true,
          use_enum_values: true,
          max_anyof_union_len: 3
        )

      opts = Config.to_json_schema_opts(config)

      assert opts[:strict] == true
      assert opts[:use_enum_values] == true
      assert opts[:max_anyof_union_len] == 3
    end

    test "to_json_schema_opts includes generator functions" do
      title_gen = fn field -> field |> Atom.to_string() |> String.capitalize() end
      desc_gen = fn field -> "Field for #{field}" end

      config =
        Config.create(
          title_generator: title_gen,
          description_generator: desc_gen
        )

      opts = Config.to_json_schema_opts(config)

      assert opts[:title_generator] == title_gen
      assert opts[:description_generator] == desc_gen
    end
  end

  describe "utility functions" do
    test "allow_extra_fields? returns correct boolean" do
      assert Config.allow_extra_fields?(Config.create(extra: :allow)) == true
      assert Config.allow_extra_fields?(Config.create(extra: :forbid)) == false
      assert Config.allow_extra_fields?(Config.create(extra: :ignore)) == true
    end

    test "should_coerce? returns correct boolean" do
      assert Config.should_coerce?(Config.create(coercion: :none)) == false
      assert Config.should_coerce?(Config.create(coercion: :safe)) == true
      assert Config.should_coerce?(Config.create(coercion: :aggressive)) == true
    end

    test "coercion_level returns the coercion strategy" do
      assert Config.coercion_level(Config.create(coercion: :none)) == :none
      assert Config.coercion_level(Config.create(coercion: :safe)) == :safe
      assert Config.coercion_level(Config.create(coercion: :aggressive)) == :aggressive
    end

    test "summary provides configuration overview" do
      config =
        Config.create(
          strict: true,
          extra: :forbid,
          coercion: :safe,
          frozen: true,
          error_format: :simple,
          validate_assignment: true,
          use_enum_values: true
        )

      summary = Config.summary(config)

      assert summary[:validation_mode] == "strict"
      assert summary[:extra_fields] == "forbidden"
      assert summary[:coercion] == "safe"
      assert summary[:frozen] == true
      assert summary[:error_format] == "simple"
      assert "validate_assignment" in summary[:features]
      assert "use_enum_values" in summary[:features]
    end

    test "summary handles lenient mode" do
      config = Config.create(strict: false, extra: :allow)
      summary = Config.summary(config)

      assert summary[:validation_mode] == "lenient"
      assert summary[:extra_fields] == "allowed"
    end

    test "summary handles ignore mode for extra fields" do
      config = Config.create(extra: :ignore)
      summary = Config.summary(config)

      assert summary[:extra_fields] == "ignored"
    end
  end

  describe "builder integration" do
    test "builder creates config" do
      config = Config.builder()

      assert %Config.Builder{} = config
      assert config.opts == %{}
    end

    test "builder can be used to create complex configurations" do
      config =
        Config.builder()
        |> Config.Builder.strict(true)
        |> Config.Builder.forbid_extra()
        |> Config.Builder.safe_coercion()
        |> Config.Builder.detailed_errors()
        |> Config.Builder.frozen(true)
        |> Config.Builder.build()

      assert config.strict == true
      assert config.extra == :forbid
      assert config.coercion == :safe
      assert config.error_format == :detailed
      assert config.frozen == true
    end
  end

  describe "advanced configuration scenarios" do
    test "configuration for different environments" do
      dev_config = Config.preset(:development)
      prod_config = Config.preset(:production)

      # Development should be permissive
      assert dev_config.strict == false
      assert dev_config.extra == :allow
      assert dev_config.coercion == :aggressive

      # Production should be strict
      assert prod_config.strict == true
      assert prod_config.extra == :forbid
      assert prod_config.frozen == true
    end

    test "configuration inheritance and customization" do
      # Use a non-frozen base config for inheritance testing
      base_config =
        Config.create(%{
          strict: true,
          extra: :forbid,
          coercion: :safe,
          validate_assignment: true,
          case_sensitive: true,
          error_format: :detailed
        })

      custom_config =
        Config.merge(base_config, %{
          error_format: :minimal,
          case_sensitive: false
        })

      # Should inherit from base config
      assert custom_config.strict == true
      assert custom_config.extra == :forbid
      assert custom_config.frozen == false

      # Should apply customizations
      assert custom_config.error_format == :minimal
      assert custom_config.case_sensitive == false
    end

    test "configuration with custom generator functions" do
      title_fn = fn field ->
        field
        |> Atom.to_string()
        |> String.split("_")
        |> Enum.map_join(" ", &String.capitalize/1)
      end

      desc_fn = fn field -> "Generated description for #{field}" end

      config =
        Config.create(
          title_generator: title_fn,
          description_generator: desc_fn
        )

      assert is_function(config.title_generator, 1)
      assert is_function(config.description_generator, 1)
      assert config.title_generator.(:user_name) == "User Name"
      assert config.description_generator.(:email) == "Generated description for email"
    end

    test "configuration validation prevents inconsistent states" do
      # Should prevent creating clearly inconsistent configurations
      invalid_configs = [
        %{strict: true, extra: :allow},
        %{coercion: :aggressive, validate_assignment: true},
        %{max_anyof_union_len: -1}
      ]

      for invalid_opts <- invalid_configs do
        config = Config.create(invalid_opts)
        assert {:error, _reasons} = Config.validate_config(config)
      end
    end

    test "configuration supports runtime modification patterns" do
      # Test the DSPy pattern: ConfigDict(extra="forbid", frozen=True)
      base_config = Config.create()

      # Should be able to create modified versions
      strict_config = Config.merge(base_config, %{strict: true, extra: :forbid})
      frozen_config = Config.merge(strict_config, %{frozen: true})

      assert frozen_config.strict == true
      assert frozen_config.extra == :forbid
      assert frozen_config.frozen == true

      # Frozen config should prevent further modification
      assert_raise RuntimeError, fn ->
        Config.merge(frozen_config, %{strict: false})
      end
    end
  end

  describe "edge cases and error handling" do
    test "handles empty configuration gracefully" do
      config = Config.create(%{})

      # Should use all default values
      assert config.strict == false
      assert config.extra == :allow
      assert config.coercion == :safe
    end

    test "validates configuration option types" do
      # These should raise or handle type errors gracefully
      invalid_options = [
        %{strict: "not_boolean"},
        %{extra: :invalid_strategy},
        %{coercion: :invalid_strategy},
        %{max_anyof_union_len: "not_integer"}
      ]

      for invalid_opts <- invalid_options do
        assert_raise ArgumentError, fn ->
          Config.create(invalid_opts)
        end
      end
    end

    test "config serialization and deserialization" do
      original_config =
        Config.create(
          strict: true,
          extra: :forbid,
          coercion: :safe,
          frozen: false
        )

      # Should be able to convert to map and back
      config_map = Map.from_struct(original_config)
      restored_config = Config.create(config_map)

      assert restored_config.strict == original_config.strict
      assert restored_config.extra == original_config.extra
      assert restored_config.coercion == original_config.coercion
    end
  end
end
