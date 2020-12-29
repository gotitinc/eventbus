defmodule Eventbus.Mixfile do
  use Mix.Project

  def project do
    [
      app: :eventbus,
      version: "0.0.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test,
                          "coveralls.post": :test, "coveralls.html": :test],
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Eventbus.Application, []},
      extra_applications: [:logger, :runtime_tools, :phoenix_pubsub, :redix, :stats]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:poison, "~> 4.0.1"},
      {:httpoison, "~> 1.7.0"},
      {:elixir_uuid, "~> 1.2.1"},
      {:phoenix_pubsub, "~> 2.0.0"},
      {:libring, "~> 1.5.0"},
      {:maptu, "~> 1.0"},
      {:redix, "~> 1.0.0"},
      {:mox, "~> 1.0.0", only: :test},
      {:credo, "~> 1.5.3", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.13.4", only: :test},
      {:stats, in_umbrella: true},
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    []
  end
end
