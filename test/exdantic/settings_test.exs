defmodule Exdantic.SettingsTest do
  use ExUnit.Case, async: true

  alias Exdantic.Settings

  defmodule OverrideSchema do
    use Exdantic

    schema do
      field(:db_url, :string, required: true, extra: %{"env" => "DATABASE_URL"})
    end
  end

  defmodule DatabaseSchema do
    use Exdantic

    schema do
      field(:host, :string, required: true)
      field(:pool_size, :integer, required: true)
    end
  end

  defmodule NestedSettingsSchema do
    use Exdantic

    schema do
      field(:database, DatabaseSchema, required: true)
    end
  end

  defmodule BoolSchema do
    use Exdantic

    schema do
      field(:enabled, :boolean, required: true)
    end
  end

  defmodule AtomSchema do
    use Exdantic

    schema do
      field(:mode, :atom, required: true)
    end
  end

  defmodule ArraySchema do
    use Exdantic

    schema do
      field(:tags, {:array, :integer}, required: true)
    end
  end

  defmodule InputSchema do
    use Exdantic

    schema do
      field(:port, :integer, default: 4000)
    end
  end

  test "override key is absolute and wins over derived prefixed key" do
    env = %{
      "APP_DB_URL" => "from-derived",
      "DATABASE_URL" => "from-override"
    }

    assert {:ok, result} = Settings.load(OverrideSchema, env: env, env_prefix: "APP_")
    assert result.db_url == "from-override"
  end

  test "returns env_key_conflict on case-insensitive collisions" do
    env = %{"app_port" => "1", "APP_PORT" => "2"}

    assert {:error, errors} = Settings.load(OverrideSchema, env: env, case_sensitive: false)
    assert Enum.any?(errors, &(&1.code == :env_key_conflict))
  end

  test "exploded nested env values override top-level JSON for same subfield" do
    env = %{
      "APP_DATABASE" => ~s({"host":"a","pool_size":5}),
      "APP_DATABASE__POOL_SIZE" => "10"
    }

    assert {:ok, result} =
             Settings.load(NestedSettingsSchema,
               env: env,
               env_prefix: "APP_",
               env_nested_delimiter: "__"
             )

    assert result.database.host == "a"
    assert result.database.pool_size == 10
  end

  test "single underscore delimiter supports exploded nested fields with underscore names" do
    env = %{
      "APP_DATABASE_HOST" => "localhost",
      "APP_DATABASE_POOL_SIZE" => "10"
    }

    assert {:ok, result} =
             Settings.load(NestedSettingsSchema,
               env: env,
               env_prefix: "APP_",
               env_nested_delimiter: "_"
             )

    assert result.database.host == "localhost"
    assert result.database.pool_size == 10
  end

  test "minimal boolean parsing accepts true/false and 1/0 only" do
    for {token, expected} <- [{"TRUE", true}, {"false", false}, {"1", true}, {"0", false}] do
      assert {:ok, result} = Settings.load(BoolSchema, env: %{"ENABLED" => token})
      assert result.enabled == expected
    end

    assert {:error, errors} = Settings.load(BoolSchema, env: %{"ENABLED" => "yes"})
    assert Enum.any?(errors, &(&1.code == :env_cast))
  end

  test "atom env casting is disabled by default and supports existing atoms when opted in" do
    _existing = :existing_mode

    assert {:error, errors} = Settings.load(AtomSchema, env: %{"MODE" => "existing_mode"})
    assert Enum.any?(errors, &(&1.code == :env_cast))

    assert {:ok, result} =
             Settings.load(AtomSchema, env: %{"MODE" => "existing_mode"}, allow_atoms: :existing)

    assert result.mode == :existing_mode

    assert {:error, errors} =
             Settings.load(AtomSchema,
               env: %{"MODE" => "definitely_missing_atom"},
               allow_atoms: :existing
             )

    assert Enum.any?(errors, &(&1.code == :env_cast))
  end

  test "structured types require JSON and invalid JSON returns env_json error" do
    assert {:ok, result} = Settings.load(ArraySchema, env: %{"TAGS" => "[1,2,3]"})
    assert result.tags == [1, 2, 3]

    assert {:error, errors} = Settings.load(ArraySchema, env: %{"TAGS" => "not-json"})
    assert Enum.any?(errors, &(&1.code == :env_json))
  end

  test "returns type error when input option is not a map" do
    assert {:error, [error]} = Settings.load(InputSchema, env: %{}, input: 123)
    assert error.code == :type
    assert error.message == "expected :input to be a map, got 123"
  end
end
