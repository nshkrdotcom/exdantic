defmodule Exdantic.MixProject do
  use Mix.Project
  @source_url "https://github.com/nshkrdotcom/exdantic"
  @version "0.0.2"

  def project do
    [
      app: :exdantic,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Advanced schema definition and validation library for Elixir",
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      package: package(),
      docs: docs(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # For JSON handling
      {:jason, "~> 1.4.4"},

      # Dev tools
      {:stream_data, "~> 1.2", only: [:test, :dev]},
      {:benchee, "~> 1.4", only: [:test, :dev]},
      {:benchee_html, "~> 1.0.1", only: [:test, :dev]},
      {:excoveralls, "~> 0.18.5", only: :test},
      {:credo, "~> 1.7.12", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38.2", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      "test.watch": ["test --listen-on-stdin"],
      "test.struct": ["test test/struct_pattern/"],
      "test.integration": ["test --include integration"],
      benchmark: ["run benchmarks/struct_performance.exs"]
    ]
  end

  defp package do
    [
      name: "exdantic",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["NSHkr"],
      files: ~w(lib examples .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        {"README.md", [filename: "readme"]},
        "LICENSE",
        {"examples/README.md", [filename: "examples"]}
      ]
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      flags: [
        :error_handling,
        :underspecs,
        :unknown,
        :unmatched_returns
      ],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end
end
