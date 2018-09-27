defmodule UdpExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :udp_example,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :brahman],
      mod: {UdpExample.Application, []}
    ]
  end

  defp deps do
    [
      {:brahman, github: "shun159/brahman", branch: "develop"},
      {:lager, ">= 3.5.2", override: true, manager: :rebar3},
      {:bear, ">= 0.8.5", override: true, manger: :rebar3}
    ]
  end
end
