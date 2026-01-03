defmodule KPD.MixProject do
  use Mix.Project

  def project do
    [
      app: :kpd,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {KPD.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.18"},
      {:nimble_csv, "~> 1.2"},
      {:bandit, "~> 1.8"},
      {:plug, "~> 1.16"},
      {:burrito, "~> 1.0"},
      {:exsync, "~> 0.4", only: :dev},
      {:tidewave, "~> 0.4", only: :dev}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      start:
        "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 8080) end)'"
    ]
  end

  def releases do
    [
      kpd_server: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_intel: [os: :darwin, cpu: :x86_64],
            macos_apple_silicon: [os: :darwin, cpu: :aarch64],
            linux_amd64: [os: :linux, cpu: :x86_64],
            linux_arm64: [os: :linux, cpu: :aarch64]
          ],
          extra_steps: [
            patch: [post: [KPD.Release.ImportDataStep]]
          ]
        ]
      ]
    ]
  end
end
