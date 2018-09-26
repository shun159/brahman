defmodule NFQ.MixProject do
  use Mix.Project

  def project do
    [
      app: :nfq,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :netlink, :pkt, :brahman],
      mod: {NFQ.Application, []}
    ]
  end

  defp deps do
    [
      {:netlink, github: "shun159/netlink", branch: "develop"},
      {:brahman, github: "shun159/brahman", branch: "develop"},
      {:pkt, github: "msantos/pkt"},
      {:lager, ">= 3.5.2", override: true, manager: :rebar3},
      {:bear, ">= 0.8.5", override: true, manger: :rebar3}
    ]
  end
end
