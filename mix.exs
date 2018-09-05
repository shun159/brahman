defmodule Brahman.MixProject do
  use Mix.Project

  def project do
    [
      app: :brahman,
      name: "Brahman",
      version: "0.1.0",
      elixir: "~> 1.7",
      description: description(),
      package: package(),
      source_url: "https://github.com/shun159/brahman",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :erldns, :folsom, :elixometer, :maru, :cowboy, :jason, :sasl],
      mod: {Brahman.Application, []}
    ]
  end

  # private functions

  defp package do
    [
      name: "brahman",
      files: ["lib", "mix.exs", "README.md", "priv"],
      licenses: ["BSD 3-Clause"],
      maintainers: ["Eishun Kondoh (shun159)"],
      links: %{"GitHub" => "https://github.com/shun159/brahman"}
    ]
  end

  defp description do
    "DNS forwarder/server utilities for Elixir"
  end

  defp deps do
    [
      # Core: DNS libraries and pipeline processing libraries
      {:erldns, github: "dcos/erl-dns"},
      {:gen_stage, "~> 0.14"},
      # Core: Instrumentation
      {:meck, "~> 0.8.9", override: true},
      {:folsom, github: "boundary/folsom", branch: "master", override: true},
      {:exometer_core, github: "esl/exometer_core", override: true},
      {:elixometer, github: "pinterest/elixometer"},
      {:parse_trans, "~> 3.2.0", override: true},
      # Core: REST
      {:maru, "~> 0.13"},
      {:cowboy, "~> 2.4"},
      {:jason, "~> 1.0"},
      # Logging
      {:lager, ">= 3.5.2", override: true, manager: :rebar3},
      # Code Quality
      {:credo, "~> 0.10.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.14", only: :dev}
    ]
  end

  defp aliases do
    [
      test: "test --no-start",
      quality: ["compile", "dialyzer", "credo --strict"]
    ]
  end

  defp dialyzer do
    [
      check_plt: true,
      plt_add_deps: :app_tree,
      flags: [:unmatched_returns, :error_handling, :race_conditions],
      ignore_warnings: "dialyzer.ignore-warnings"
    ]
  end
end
