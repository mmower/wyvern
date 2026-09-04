defmodule Wyvern.MixProject do
  use Mix.Project

  def project do
    [
      app: :wyvern,
      description: "Wyvern is an Elixir builder API for constructing LLVM IR",
      version: "1.0.7",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: Path.wildcard("lib/**/*.ex") ++ ~w(mix.exs README.md LICENSE.txt),
      # Must be valid SPDX license identifiers
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com",
        "Docs" => "https://hexdocs.pm"
      }
    ]
  end
end
