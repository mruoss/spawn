defmodule Statestores.MixProject do
  use Mix.Project

  @app :spawn_statestores

  def project do
    [
      app: @app,
      version: "0.1.0",
      description: "Spawn Statestores is the storage lib for the Spawn Actors System",
      source_url: "https://github.com/eigr/spawn/tree/main/spawn_statestores/statestores",
      homepage_url: "https://eigr.io/",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      package: [
        licenses: ["Apache-2.0"],
        links: %{"GitHub" => "https://github.com/eigr/spawn"}
      ]
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
      {:vapor, "~> 0.10"},
      {:cloak_ecto, "~> 1.2"},
      {:ecto_sql, "~> 3.8"},
      {:ecto_sqlite3, "~> 0.8.2"},
      {:myxql, "~> 0.6"},
      {:postgrex, "~> 0.16"},
      {:tds, "~> 2.3"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
