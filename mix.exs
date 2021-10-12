defmodule ExKdl.MixProject do
  use Mix.Project

  @version "0.1.0-rc2"
  @source_url "https://github.com/benjreinhart/ex_kdl"

  def project do
    [
      app: :ex_kdl,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "ex_kdl",
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:decimal, "~> 2.0"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end

  defp description() do
    """
    A robust and efficient decoder and encoder for the KDL document language.
    """
  end

  defp package() do
    [
      maintainers: ["Ben Reinhart"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs() do
    [
      main: "readme",
      name: "ex_kdl",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/ex_kdl",
      source_url: @source_url,
      extras: ["README.md", "LICENSE.txt"]
    ]
  end
end
