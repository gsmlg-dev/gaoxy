defmodule Mix.Tasks.Gaoxy.Validate do
  @shortdoc "Validate a version 1 JSON configuration without opening listeners"
  use Mix.Task
  @impl true
  def run([path]) do
    Mix.Task.run("compile")

    case Gaoxy.Server.Config.load(path) do
      {:ok, _} -> Mix.shell().info("valid")
      {:error, reason} -> Mix.raise("invalid configuration: #{inspect(reason)}")
    end
  end

  def run(_), do: Mix.raise("usage: mix gaoxy.validate CONFIG.json")
end
