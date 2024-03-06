defmodule CredoPureCheck.MixProject do
  use Mix.Project

  def project do
    [
      app: :credo_pure_check,
      version: "0.2.3",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A custom Credo check to verify that modules are pure",
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
      {:credo, "~> 1.7.5"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Charles Bernasconi"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/chazsconi/credo_pure_check.git"}
    ]
  end
end
