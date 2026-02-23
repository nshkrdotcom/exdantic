defmodule Exdantic.MixProject do
  use Mix.Project
  @source_url "https://github.com/nshkrdotcom/exdantic"
  @version "0.1.0"

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
      {:ex_doc, "~> 0.40.0", only: :dev, runtime: false}
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
      files: ~w(lib examples guides .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      logo: "assets/exdantic.svg",
      assets: %{"assets" => "assets"},
      extras: [
        {"README.md", [filename: "readme", title: "Overview"]},
        {"guides/01_overview_and_quickstart.md", [title: "01. Overview and Quickstart"]},
        {"guides/02_schema_dsl_and_types.md", [title: "02. Schema DSL and Types"]},
        {"guides/03_structs_model_validators_computed_fields.md",
         [title: "03. Structs, Model Validators, and Computed Fields"]},
        {"guides/04_runtime_schemas.md", [title: "04. Runtime Schemas"]},
        {"guides/05_type_adapter_wrapper_root_schema.md",
         [title: "05. TypeAdapter, Wrapper, and RootSchema"]},
        {"guides/06_json_schema_and_resolvers.md", [title: "06. JSON Schema and Resolvers"]},
        {"guides/07_llm_and_dspy_workflows.md", [title: "07. LLM and DSPy Workflows"]},
        {"guides/08_configuration_and_settings.md", [title: "08. Configuration and Settings"]},
        {"guides/09_errors_reports_and_operations.md",
         [title: "09. Errors, Reports, and Operations"]},
        {"CHANGELOG.md", [title: "Changelog"]},
        "LICENSE",
        {"examples/README.md", [filename: "examples", title: "Examples Index"]}
      ],
      groups_for_extras: [
        "Guides: Foundations": Path.wildcard("guides/0[1-3]_*.md"),
        "Guides: Runtime and Schemas": Path.wildcard("guides/0[4-6]_*.md"),
        "Guides: Integration and Ops": Path.wildcard("guides/0[7-9]_*.md"),
        Project: ["README.md", "CHANGELOG.md", "LICENSE", "examples/README.md"]
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
      ]
    ]
  end
end
