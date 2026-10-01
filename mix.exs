defmodule BtrzExPlug.MixProject do
  use Mix.Project

  @github_url "https://github.com/Betterez/btrz_ex_plug"
  @version "0.2.0"

  def project do
    [
      app: :btrz_ex_plug,
      version: @version,
      name: "BtrzExPlug",
      description: "Elixir package that groups all betterez plugs",
      source_url: @github_url,
      homepage_url: @github_url,
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:plug, "~> 1.4"},
      {:excoveralls, "~> 0.8", only: :test},
      {:phoenix_swagger, "~> 0.8.0"},
      {:ex_json_schema, "~> 0.5"},
      {:recase, "~> 0.4.0"},
      {:httpoison, "~> 1.0"},
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry, "~> 1.5", only: :test}
    ]
  end

  defp docs do
    [
      main: "BtrzExPlug",
      source_ref: "v#{@version}",
      source_url: @github_url,
      extras: ["README.md"]
    ]
  end

  defp aliases do
    []
  end

  defp package do
    %{
      name: "btrz_ex_plug",
      licenses: ["MIT"],
      maintainers: ["Hernán García", "Pablo Brudnick", "Facundo Soria Guerrero", "Agustin Croce"],
      links: %{"GitHub" => @github_url}
    }
  end
end
