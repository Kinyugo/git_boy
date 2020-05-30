defmodule GitBoy.Repositories.GitHubAPI do
  @moduledoc """
  GitBoy.Repositories.GitHubAPI provides functions
  for sending HTTP requests to GitHub to search repositories.
  """
  alias GitBoy.Repositories.Repository

  @github_repositories_url "https://api.github.com/search/repositories?"

  @typedoc """
  Type that represents the contents of type params,
  it can be `String` or `nil`.
  """
  @type param() :: String.t() | nil

  @typedoc """
  Type that represents the argument taken by `search_for_repositories`
  function with `query` of type list of type `param`, `sort` of type `param`
  `order` of type `param` and `page` of type `param`.
  """
  @type params() ::
          keyword(
            query: [param()],
            sort: param(),
            order: param(),
            page: param()
          )

  # Start the HTTP client
  Application.ensure_started(:httpoison)

  ## API

  @doc """
    Fetches a list of repositories from the github api.

    ## Examples

        iex> params = [query: ["phoenix", "language:elixir"], sort: "stars", order: "desc"]
        iex> GitBoy.Repositories.search_for_repositories(params)
          [%Repository{id:16072585 ,name:"phoenixframework/phoenix",...}...]

  """
  @spec search_for_repositories(params()) :: [Repository.t()] | []
  def search_for_repositories(params \\ []) when is_list(params) do
    @github_repositories_url
    |> build_search_url(params)
    |> IO.inspect(label: "Search url")
    |> fetch_repositories_from_api()
    |> IO.inspect(label: "Fetched repos: ", limit: 2)
  end

  ## Helper functions
  defp fetch_repositories_from_api(url) do
    url
    |> HTTPoison.get()
    |> parse_api_response()
  end

  defp parse_api_response({:error, _error}), do: []

  defp parse_api_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    case Poison.decode(body) do
      {:ok, decoded_body} -> extract_repositories(decoded_body)
      {:error, _error} -> []
    end
  end

  defp parse_api_response({:ok, %HTTPoison.Response{status_code: _status_code}}), do: []

  defp extract_repositories(decoded_body) do
    decoded_body
    |> Map.get("items", [])
    |> Enum.map(fn repository_data -> Repository.parse(repository_data) end)
  end

  defp build_search_url(base_url, []), do: base_url

  defp build_search_url(base_url, params) do
    params
    |> Enum.reduce(
      base_url,
      fn param, intermediate_url -> parse_params(intermediate_url, param) <> "&" end
    )
    |> URI.encode()
  end

  defp parse_params(intermediate_url, {:page, page}) do
    concat_param_values([intermediate_url, "page=", page])
  end

  defp parse_params(intermediate_url, {:order, order}) do
    concat_param_values([intermediate_url, "order=", order])
  end

  defp parse_params(intermediate_url, {:sort, sort}) do
    concat_param_values([intermediate_url, "sort=", sort])
  end

  defp parse_params(intermediate_url, {:query, query_list})
       when length(query_list) > 0 do
    concat_param_values([intermediate_url, "q=", concat_query_list(query_list)])
  end

  defp parse_params(intermediate_url, _), do: intermediate_url

  defp concat_query_list([]), do: ""

  defp concat_query_list(query_list) do
    Enum.join(query_list, "+")
  end

  defp concat_param_values(param_values), do: Enum.join(param_values)
end
