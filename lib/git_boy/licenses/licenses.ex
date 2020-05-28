defmodule GitBoy.Licenses do
  @moduledoc """
  GitBoy.Licenses module provides functions for
  fetching a list of common licenses from the GitHub API.

  The module provides an API that allows client to read this list
  of licenses.

  Internally the module uses `Agent` to handle its state to avoid
  making HTTP request to the GitHub API every time a client makes
  a request. Hence the module should be added as a child in
  `application.ex` as follows:

  ```
  children = [
    # Other children
    ...
    GitBoy.Licenses
    ...
    # Other children
  ]
  ```
  """
  use Agent
  alias GitBoy.Licenses.License

  @github_licenses_url "https://api.github.com/licenses"

  # Start the HTTP client
  Application.ensure_started(:httpoison)

  ## API

  # Called by the supervisor when starting the child
  def start_link(_opts) do
    Agent.start_link(fn -> fetch_licenses_from_api() end, name: __MODULE__)
  end

  @doc """
  Lists all common licenses from GitHub #{@github_licenses_url}

  ## Examples

      iex> GitBoy.Licenses.list_licenses()
      [
        %GitBoy.Licenses.License{key: "mit", name: "MIT License"},
        %GitBoy.Licenses.License{key: "mpl-2.0", name: "Mozilla Public License 2.0"},
        %GitBoy.Licenses.License{key: "unlicense", name: "The Unlicense"}, ...
      ]

  """
  @spec list_licenses() :: [License.t() | nil]
  def list_licenses(), do: Agent.get(__MODULE__, & &1)

  defp fetch_licenses_from_api() do
    @github_licenses_url
    |> HTTPoison.get()
    |> parse_api_response()
  end

  defp parse_api_response({:error, _error}), do: []

  defp parse_api_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    case Poison.decode(body) do
      {:ok, data} -> extract_licenses(data)
      {:error, _reason} -> []
    end
  end

  defp parse_api_response({:ok, %HTTPoison.Response{status_code: _status_code}}), do: []

  defp extract_licenses(data), do: Enum.map(data, &License.parse/1)
end
