defmodule Ark.MixProject do
  use Mix.Project

  def project do
    [
      app: :ark,
      version: "1.0.0",
      elixir: "~> 1.18.4-otp-28",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [ignore_warnings: ".dialyzer_ignore.exs"],
      package: package(),
      description: description(),
      source_url: "https://github.com/lorenzo-sf/ark",
      homepage_url: "https://hex.pm/packages/ark",
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md", "LICENSE"],
        source_ref: "v1.0.0",
        source_url: "https://github.com/lorenzo-sf/ark"
      ],
      escript: [main_module: Ark.CLI]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :aegis, :argos, :aurora]
    ]
  end

  defp deps do
    [
      # Core dependencies - Proyecto Ypsilon
      # dependencias indirectas:
      # Level 1A - Aurora (formatting & rendering)
      # Level 1B - Argos (command execution & task orchestration)
      # Level 2 - Aegis (CLI/TUI framework)
      {:aegis, path: "../Aegis"},
      {:argos, path: "../Argos"},
      {:aurora, path: "../Aurora"},

      # External dependencies for tools
      {:docker, "~> 0.4.0"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5.10"},
      {:sweet_xml, "~> 0.7.5"},

      # Development dependencies
      {:credo, "~> 1.7.12", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.3", only: :dev},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.34", runtime: false},
      {:mix_test_watch, "~> 1.1", only: :dev, runtime: false},

      # Test dependencies
      {:propcheck, "~> 1.4", only: :test}
    ]
  end

  def escript do
    [
      main_module: Ark.CLI
    ]
  end

  defp aliases do
    [
      gen: [
        "format",
        "escript.build",
        "deploy",
        "tools_version"
      ],
      deploy: fn _ ->
        dest_dir = Path.expand("~/.Ypsilon")
        File.mkdir_p!(dest_dir)
        File.cp!("ark", Path.join(dest_dir, "ark"))
        IO.puts("✅ Escript instalado en #{dest_dir}/ark")
      end,
      tools_version: fn _ ->
        dest_dir = Path.expand("~/.Ypsilon")
        tool_versions_path = Path.join(dest_dir, ".tool-versions")

        File.write!(tool_versions_path, """
        erlang 28.1
        elixir 1.18.4-otp-28
        """)

        IO.puts("✅ Archivo .tool-versions creado en #{tool_versions_path}")
      end,
      quality: [
        "format",
        "deps.get",
        "credo --strict --format=oneline",
        "compile --warnings-as-errors",
        "cmd 'echo \"✅ mix compile terminado\"'",
        "cmd MIX_ENV=test mix test",
        "cmd 'echo \"✅ mix test terminado\"'",
        "credo --strict",
        "cmd 'echo \"✅ mix credo terminado\"'",
        "dialyzer",
        "cmd 'echo \"✅ quality terminado\"'"
      ],
      ci: [
        "deps.get",
        "clean",
        "compile --warnings-as-errors",
        "cmd MIX_ENV=test mix test",
        "credo --strict",
        "cmd 'echo \\\"terminado terminado\"'"
      ],
      hex_prepare: [
        "clean",
        "compile --force --warnings-as-errors",
        "format",
        "test",
        "docs",
        "cmd mix hex.build"
      ],
      hex_publish: [
        "hex_prepare",
        "cmd mix hex.publish"
      ]
    ]
  end

  defp description do
    """
    Ark: microframework global para herramientas de desarrollo en Elixir.
      Nivel 3 de Proyecto Ypsilon, que ofrece:
      > Gestión integral del sistema
      > Operaciones con Docker
      > Flujos de trabajo de Git
      > Administración de SSH
      > Utilidades de desarrollo

    Construido sobre Aurora, Argos y Aegis.
    """
  end

  defp package do
    [
      name: "ark",
      licenses: ["Apache-2.0"],
      maintainers: ["Lorenzo Sánchez Fraile"],
      links: %{
        "GitHub" => "https://github.com/lorenzo-sf/ark",
        "Docs" => "https://hexdocs.pm/ark",
        "Changelog" => "https://github.com/lorenzo-sf/ark/blob/main/CHANGELOG.md"
      },
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE .dialyzer_ignore.exs)
    ]
  end
end
