defmodule GitBoy.Repositories do
  @moduledoc """
  GitBoy.Repositories module provides functions
  for fetching repositories from the GitHub API
  based on queries.

  The module also provides function for filtering
  the list of repositories from GitHub.
  """
  use GenServer
  alias GitBoy.Repositories.GitHubAPI
  alias GitBoy.Repositories.Repository

  @default_cache_timeout 120_000
  @default_query_params [query: ["language:elixir"], sort: "stars", order: "desc"]
  @default_cache_vsn 1

  def start_link(opts) when is_list(opts) do
    # Extract values for the initial query to send to github and also the
    # timeout after which to clean the cache
    {cache_timeout, opts} = Keyword.pop(opts, :cache_timeout, @default_cache_timeout)
    {query_params, opts} = Keyword.pop(opts, :query_params, @default_query_params)

    init_args = [
      cache_timeout: cache_timeout,
      query_params: query_params,
      cache_vsn: @default_cache_vsn
    ]

    GenServer.start_link(__MODULE__, init_args, opts)
  end

  def is_empty?(repo_server) do
    repo_server
    |> list_repositories()
    |> Enum.empty?()
  end

  @spec filter_by_name(atom | pid | {atom, any} | {:via, atom, any}, String.t()) ::
          [Repository.t()] | []
  def filter_by_name(repo_server, repo_name) do
    repo_server
    |> list_repositories()
    |> Enum.filter(fn repo -> has_substr?(repo.name, repo_name) end)
  end

  @spec filter_by_language(atom | pid | {atom, any} | {:via, atom, any}, String.t()) ::
          [Repository.t()] | []
  def filter_by_language(repo_server, language) do
    repo_server
    |> list_repositories()
    |> Enum.filter(fn repo -> equivalent_strings?(repo.language, language) end)
  end

  @spec list_repositories(atom | pid | {atom, any} | {:via, atom, any}) :: [Repository.t()] | []
  def list_repositories(repo_server) do
    GenServer.call(repo_server, :list_repositories)
  end

  def refetch_repositories(repo_server) do
    GenServer.call(repo_server, :refetch_repositories)
  end

  @spec fetch_repositories(atom | pid | {atom, any} | {:via, atom, any}, GitHubAPI.params()) ::
          [Repository.t()] | []
  def fetch_repositories(repo_server, query_params) do
    GenServer.call(repo_server, {:fetch_repositories, query_params})
  end

  ## Server
  @impl true
  def init(cache_timeout: cache_timeout, query_params: query_params, cache_vsn: cache_vsn) do
    # Fetch a list of repositories from github
    repositories = GitHubAPI.search_for_repositories(query_params)

    # Schedule cache cleanup after the given timeout
    schedule_cache_cleanup({cache_vsn, cache_timeout})

    {:ok,
     %{
       repositories: repositories,
       cache_timeout: cache_timeout,
       cache_vsn: cache_vsn,
       query_params: query_params
     }}
  end

  @impl true
  def handle_call(:list_repositories, _from, %{repositories: repositories} = state) do
    {:reply, repositories, state}
  end

  @impl true
  def handle_call(
        :refetch_repositories,
        _from,
        %{cache_timeout: cache_timeout, query_params: query_params} = state
      ) do
    # Fetch repositories from github api using the previous query.
    repositories = GitHubAPI.search_for_repositories(query_params)

    new_state =
      state
      |> update_repositories(repositories)
      |> update_cache_vsn()

    # Schedule cleanup for the updated vsn of the cache
    cache_vsn = Map.get(state, :cache_vsn)
    schedule_cache_cleanup({cache_vsn, cache_timeout})

    {:reply, repositories, new_state}
  end

  @impl true
  def handle_call(
        {:fetch_repositories, query_params},
        _from,
        %{cache_timeout: cache_timeout} = state
      ) do
    # Fetch repositories from github api
    repositories = GitHubAPI.search_for_repositories(query_params)

    new_state =
      state
      |> update_repositories(repositories)
      |> update_cache_vsn()
      |> update_query_params(query_params)

    # Schedule cleanup for the updated version of the cache
    cache_vsn = Map.get(state, :cache_vsn)
    schedule_cache_cleanup({cache_vsn, cache_timeout})

    {:reply, repositories, new_state}
  end

  @impl true
  def handle_info(
        {:clean_cache, vsn},
        %{cache_timeout: cache_timeout, cache_vsn: cache_vsn} = state
      ) do
    # Schedule next cache cleanup
    schedule_cache_cleanup({cache_vsn, cache_timeout})

    # Prevent cleaning of recently fetched repositories by old `:clean_cache` requests.
    new_state =
      if cache_vsn == vsn do
        update_repositories(state, [])
      else
        state
      end

    {:noreply, new_state}
  end

  ## Helpers
  defp equivalent_strings?(first_string, second_string)
       when is_binary(first_string) and is_binary(second_string) do
    String.equivalent?(String.downcase(first_string), String.downcase(second_string))
  end

  defp equivalent_strings?(_, _), do: false

  defp has_substr?(name, substr) do
    String.contains?(String.downcase(name), String.downcase(substr))
  end

  defp update_query_params(state, new_query_params) do
    Map.put(state, :query_params, new_query_params)
  end

  defp update_cache_vsn(state) do
    Map.update(state, :cache_vsn, @default_cache_vsn, &(&1 + 1))
  end

  defp update_repositories(state, new_value) do
    Map.put(state, :repositories, new_value)
  end

  defp schedule_cache_cleanup({cache_vsn, timeout}) do
    Process.send_after(self(), {:clean_cache, cache_vsn}, timeout)
  end
end
