# Comprehensive Exdantic.Settings example
# Run with: mix run examples/settings_loader.exs

Mix.Task.run("compile")

defmodule SettingsLoaderExample do
  alias Exdantic.Settings

  defmodule DatabaseConfig do
    use Exdantic

    schema do
      field(:host, :string, required: true)
      field(:pool_size, :integer, default: 5)
    end
  end

  defmodule AppConfig do
    use Exdantic, define_struct: true

    schema "Settings schema for a sample service" do
      field(:name, :string, default: "exdantic-service")
      field(:port, :integer, default: 4000)
      field(:enabled, :boolean, default: true)
      field(:mode, :atom, default: :safe)
      field(:database, DatabaseConfig, required: true)
      field(:tags, {:array, :string}, default: [])
      field(:database_url, :string, required: true, extra: %{"env" => "DATABASE_URL"})
    end
  end

  def run do
    IO.puts("=== Exdantic.Settings Comprehensive Example ===")
    IO.puts("")

    successful_load_demo()
    input_precedence_demo()
    empty_string_behavior_demo()
    case_collision_demo()
    invalid_json_demo()
    from_system_env_demo()
  end

  defp successful_load_demo do
    IO.puts("1) Successful load with prefixing, nested merge, and absolute override")
    env = baseline_env()

    {:ok, settings} =
      Settings.load(AppConfig,
        env: env,
        env_prefix: "APP_",
        env_nested_delimiter: "__",
        allow_atoms: :existing,
        ignore_empty: true
      )

    IO.inspect(settings, label: "Loaded settings")
    IO.puts("Derived key APP_DATABASE_URL is ignored because DATABASE_URL override wins.")
    IO.puts("")
  end

  defp input_precedence_demo do
    IO.puts("2) Explicit input has higher precedence than env values")
    env = baseline_env()

    {:ok, settings} =
      Settings.load(AppConfig,
        env: env,
        env_prefix: "APP_",
        allow_atoms: :existing,
        input: %{port: 4200, database: %{pool_size: 20}}
      )

    IO.inspect(settings, label: "Merged settings")
    IO.puts("")
  end

  defp empty_string_behavior_demo do
    IO.puts("3) ignore_empty controls whether empty strings are treated as absent")

    env =
      baseline_env()
      |> Map.put("APP_NAME", "")

    {:ok, ignored_empty} =
      Settings.load(AppConfig,
        env: env,
        env_prefix: "APP_",
        allow_atoms: :existing,
        ignore_empty: true
      )

    {:ok, kept_empty} =
      Settings.load(AppConfig,
        env: env,
        env_prefix: "APP_",
        allow_atoms: :existing,
        ignore_empty: false
      )

    IO.inspect(ignored_empty.name, label: "ignore_empty: true")
    IO.inspect(kept_empty.name, label: "ignore_empty: false")
    IO.puts("")
  end

  defp case_collision_demo do
    IO.puts("4) Case-insensitive collisions are rejected")

    env =
      baseline_env()
      |> Map.merge(%{"app_port" => "1111", "APP_PORT" => "2222"})

    case Settings.load(AppConfig, env: env, env_prefix: "APP_", allow_atoms: :existing) do
      {:ok, _} ->
        IO.puts("Unexpected success")

      {:error, errors} ->
        IO.inspect(errors, label: "Collision errors")
    end

    IO.puts("")
  end

  defp invalid_json_demo do
    IO.puts("5) Structured fields require JSON values")

    env =
      baseline_env()
      |> Map.put("APP_TAGS", "not-json")

    case Settings.load(AppConfig, env: env, env_prefix: "APP_", allow_atoms: :existing) do
      {:ok, _} ->
        IO.puts("Unexpected success")

      {:error, errors} ->
        IO.inspect(errors, label: "JSON decode errors")
    end

    IO.puts("")
  end

  defp from_system_env_demo do
    IO.puts("6) from_system_env/2 usage")

    env_vars = %{
      "APP_DATABASE" => ~s({"host":"db.system","pool_size":7}),
      "APP_PORT" => "4300",
      "APP_MODE" => "safe",
      "DATABASE_URL" => "ecto://system@localhost/system_db"
    }

    previous = Enum.into(env_vars, %{}, fn {k, _} -> {k, System.get_env(k)} end)

    Enum.each(env_vars, fn {k, v} -> System.put_env(k, v) end)

    try do
      {:ok, settings} =
        Settings.from_system_env(AppConfig,
          env_prefix: "APP_",
          allow_atoms: :existing
        )

      IO.inspect(settings, label: "System env settings")
    after
      Enum.each(previous, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)
    end

    IO.puts("")
  end

  defp baseline_env do
    %{
      "APP_PORT" => "4100",
      "APP_ENABLED" => "0",
      "APP_MODE" => "safe",
      "APP_DATABASE" => ~s({"host":"db.local","pool_size":5}),
      "APP_DATABASE__POOL_SIZE" => "12",
      "APP_TAGS" => ~s(["settings","example"]),
      "APP_DATABASE_URL" => "ecto://derived@localhost/from_prefix",
      "DATABASE_URL" => "ecto://override@localhost/main_db"
    }
  end
end

SettingsLoaderExample.run()
