defmodule GitBoy.Repositories do
  @moduledoc """
  GitBoy.Repositories module provides functions
  for fetching repositories from the GitHub API
  based on queries.

  The module also provides function for filtering
  the list of repositories from GitHub.
  """
  use GenServer
  require Logger
  alias GitBoy.Repositories.GitHubAPI
  alias GitBoy.Repositories.Repository
  alias GitBoy.Licenses.License

  @type repositories :: [Repository.t()] | []
  @type repo_server :: atom | pid | {atom, any} | {:via, atom, any}

  @cache_timeout 120_000
  @query_params [query: ["language:elixir"], sort: "stars"]
  @cache_vsn 1
  @filter_and_sort_keys [:language, :repo_name, :license, :sort, :order]

  # Client
  def start_link(opts) do
    Logger.debug("Starting a new Repositories process ~ opts: #{inspect(opts)}")

    # Interval to clean cache
    cache_timeout = Keyword.get(opts, :cache_timeout, @cache_timeout)
    # Initial query for repositories
    query_params = Keyword.get(opts, :query_params, @query_params)

    init_arg = [
      repositories: [],
      cache_timeout: cache_timeout,
      query_params: query_params,
      cache_vsn: @cache_vsn
    ]

    GenServer.start_link(__MODULE__, init_arg)
  end

  @spec list_licenses(pid()) :: [License.t()]
  @doc """
  Lists all the licenses of the repos in state.

  ## Examples

      iex> {:ok, pid} = Repositories.start_link([])
      iex> Repositories.fetch_repositories(pid)
      iex> Repositories.list_licenses(pid)
        [%License{key: "mit", name: "MIT License"}, ...]
  """
  def list_licenses(pid) do
    GenServer.call(pid, :list_licenses)
  end

  @spec filter_and_sort(pid(), keyword()) :: repositories()
  @doc """
  Applies multiple filters to repos, sorts and orders them.

   ## Examples

      iex> {:ok, pid} = Repositories.start_link([])
      iex> Repositories.fetch_repositories(pid)
      iex> filters = [
        language: "elixir",
        repo_name: "phoenix"
        license: "mit",
        sort: "stars",
        order: "desc"
      ]
      iex> Repositories.filter_and_sort(pid, filters)
      [
        %GitBoy.Repositories.Repository{
          language: "Elixir",
          license: %GitBoy.Licenses.License{key: "mit", name: "MIT License"},
          name: "phoenixframework/phoenix",
          stargazers_count: 15328,
          ...
        },..
      ]
  """
  def filter_and_sort(pid, []), do: list_repositories(pid)

  def filter_and_sort(pid, filters_and_sort) do
    params = get_filter_and_sort_values(filters_and_sort)

    GenServer.call(pid, {:filter_and_sort, params})
  end

  @spec sort_repos(pid(), String.t(), String.t()) :: repositories()
  @doc """
  Sorts repositories based on the given criteria and the orders them
  in ascending or descending order.

   ## Examples

      iex> {:ok, pid} = Repositories.start_link([])
      iex> Repositories.fetch_repositories(pid)
      iex> Repositories.sort_repos(pid, "stars", "desc")
        [
        %GitBoy.Repositories.Repository{
          language: "Elixir",
          license: %GitBoy.Licenses.License{key: "apache-2.0", name: "Apache 2.0 License"},
          name: "elixir-lang/elixir",
          stargazers_count: 16969,
          ...
        },..
      ]
  """
  def sort_repos(pid, "", ""), do: list_repositories(pid)

  def sort_repos(pid, sort, order) do
    sorter_fn = fn repos ->
      repos
      |> sort_by(sort)
      |> order(order)
    end

    GenServer.call(pid, {:sort_and_order, sorter_fn})
  end

  @spec filter_by_license(pid(), String.t()) :: repositories()
  @doc """
  Filters repositories based on the given license.

   ## Examples

      iex> {:ok, pid} = Repositories.start_link([])
      iex> Repositories.fetch_repositories(pid)
      iex> Repositories.filter_by_license(pid, "mit")
        [
        %GitBoy.Repositories.Repository{
          language: "Elixir",
          license: %GitBoy.Licenses.License{key: "mit", name: "MIT License"},
          name: "phoenixframework/phoenix",
          stargazers_count: 15328,
          ...
        },..
      ]
  """
  def filter_by_license(pid, ""), do: list_repositories(pid)

  def filter_by_license(pid, license) do
    GenServer.call(pid, {:filter, fn repo -> has_license?(Map.get(repo, :license), license) end})
  end

  @spec filter_by_name(pid(), String.t()) :: repositories()
  @doc """
  Filters repositories by the given name.

  ## Examples

      iex> {:ok, pid} = Repositories.start_link([])
      iex> Repositories.fetch_repositories(pid)
      iex> Repositories.filter_by_name(pid, "phoenix")
        [
        %GitBoy.Repositories.Repository{
          language: "Elixir",
          license: %GitBoy.Licenses.License{key: "mit", name: "MIT License"},
          name: "phoenixframework/phoenix",
          stargazers_count: 15328,
          ...
        },..
      ]
  """
  def filter_by_name(pid, ""), do: list_repositories(pid)

  def filter_by_name(pid, repo_name) do
    GenServer.call(pid, {:filter, fn repo -> has_substr?(Map.get(repo, :name), repo_name) end})
  end

  @spec filter_by_language(pid, String.t()) :: repositories()
  @doc """
  Filters repositories by the given language.

  ## Examples

      iex> {:ok, pid} = Repositories.start_link([])
      iex> Repositories.fetch_repositories(pid)
      iex> Repositories.filter_by_language(pid, "elixir")
        [
        %GitBoy.Repositories.Repository{
          language: "Elixir",
          license: %GitBoy.Licenses.License{key: "mit", name: "MIT License"},
          name: "phoenixframework/phoenix",
          stargazers_count: 15328,
          ...
        },..
      ]
  """
  def filter_by_language(pid, ""), do: list_repositories(pid)

  def filter_by_language(pid, language) do
    GenServer.call(
      pid,
      {:filter, fn repo -> equivalent_strings?(Map.get(repo, :language), language) end}
    )
  end

  @spec fetch_repositories(pid()) :: repositories()
  @doc """
  Fetches repositories from github using the default query `@query_params`.

  ## Examples

      iex> {:ok, pid} = Repositories.start_link([])
      iex> Repositories.fetch_repositories(pid)
        [
        %GitBoy.Repositories.Repository{
          language: "Elixir",
          license: %GitBoy.Licenses.License{key: "mit", name: "MIT License"},
          name: "phoenixframework/phoenix",
          stargazers_count: 15328,
          ...
        },..
      ]
  """
  def fetch_repositories(pid), do: fetch_repositories(pid, @query_params)

  @spec fetch_repositories(pid(), GitHubAPI.params() | keyword()) :: repositories()
  @doc """
  Fetches repositories from github based on the given params.

  ## Examples

      iex> {:ok, pid} = Repositories.start_link([])
      iex> params = [query: ["freecodecamp", "language:javascript"], sort: "stars", order: "desc"]
      iex> Repositories.fetch_repositories(pid, params)
        [
        %GitBoy.Repositories.Repository{
          language: "JavaScript",
          license: %GitBoy.Licenses.License{
            key: "bsd-3-clause",
            name: "BSD 3-Clause \"New\" or \"Revised\" License"
          },
          name: "freeCodeCamp/freeCodeCamp",
          stargazers_count: 311433,
          url: "https://github.com/freeCodeCamp/freeCodeCamp",
          ...
        },...
      ]
  """
  def fetch_repositories(pid, query_params) do
    GenServer.call(pid, {:fetch_repositories, query_params}, :infinity)
  end

  @spec list_repositories(pid()) :: repositories()
  @doc """
  Lists repositories currently stored in the repo server.

   ## Examples

      iex> {:ok, pid} = Repositories.start_link([])
      iex> params = [query: ["freecodecamp", "language:javascript"], sort: "stars", order: "desc"]
      iex> Repositories.fetch_repositories(pid, params)
      iex> Repositories.list_repositories(pid)
      [
        %GitBoy.Repositories.Repository{
          language: "JavaScript",
          license: %GitBoy.Licenses.License{
            key: "bsd-3-clause",
            name: "BSD 3-Clause \"New\" or \"Revised\" License"
          },
          name: "freeCodeCamp/freeCodeCamp",
          stargazers_count: 311433,
          url: "https://github.com/freeCodeCamp/freeCodeCamp",
          ...
        },...
      ]
  """

  def list_repositories(pid) do
    GenServer.call(pid, :list_repositories)
  end

  @spec is_empty?(pid()) :: boolean()
  @doc """
  Returns `true` if no repositories are currently stored in the repo server
  `false` otherwise.

  ## Examples

      iex> {:ok, pid} = Repositories.start_link([])
      iex> Repositories.is_empty?(pid)
        true
      iex> Repositories.fetch_repositories(pid)
      iex> Repositories.is_empty?(pid)
        false
  """
  def is_empty?(pid) do
    GenServer.call(pid, :is_empty?)
  end

  # Server (callbacks)

  @impl true
  def init(state) do
    {:ok, Map.new(state)}
  end

  @impl true
  def handle_call(:list_licenses, _from, state) do
    licenses =
      state
      |> get_repositories()
      |> extract_licenses()

    {:reply, licenses, state}
  end

  @impl true
  def handle_call({:filter_and_sort, params}, _from, state) do
    [language, repo_name, license, sort, order] = params

    repos =
      state
      |> get_repositories()
      |> Enum.filter(fn repo ->
        name_filter_fn(repo, repo_name) &&
          language_filter_fn(repo, language) &&
          license_filter_fn(repo, license)
      end)
      |> sort_by(sort)
      |> order(order)

    {:reply, repos, state}
  end

  @impl true
  def handle_call({:sort_and_order, sorter_fn}, _from, state) do
    repos = get_repositories(state)
    sorted_repos = sorter_fn.(repos)

    {:reply, sorted_repos, state}
  end

  @impl true
  def handle_call({:filter, filter_fn}, _from, state) do
    repos =
      state
      |> get_repositories()
      |> Enum.filter(filter_fn)

    {:reply, repos, state}
  end

  @impl true
  def handle_call(:is_empty?, _from, state) do
    is_empty =
      state
      |> get_repositories()
      |> Enum.empty?()

    {:reply, is_empty, state}
  end

  @impl true
  def handle_call(:list_repositories, _from, state) do
    repos = get_repositories(state)

    {:reply, repos, state}
  end

  @impl true
  def handle_call({:fetch_repositories, query_params}, _from, state) do
    # Fetch repos from API
    repos = GitHubAPI.search_for_repositories(query_params)

    # Update state
    new_state =
      state
      |> update_repositories(repos)
      |> update_cache_vsn()
      |> update_query_params(query_params)

    # Schedule cache cleanup job
    cache_config = get_cache_config(state)
    schedule_cache_cleanup(cache_config)

    {:reply, repos, new_state}
  end

  @impl true
  def handle_info({:clean_cache, cache_vsn}, state) do
    # Clean cache if the version set up for cleaning
    # and the version currently in the state match
    %{cache_vsn: current_cache_vsn} = cache_config = get_cache_config(state)

    new_state =
      case cache_vsn == current_cache_vsn do
        true ->
          update_repositories(state, [])

        _ ->
          state
      end

    # Reschedule next cache cleanup
    schedule_cache_cleanup(cache_config)

    {:noreply, new_state}
  end

  # Helpers

  defp extract_licenses([]), do: []

  defp extract_licenses(repositories) do
    repositories
    |> Enum.map(fn repo -> Map.get(repo, :license) end)
    |> Enum.filter(&(&1 != nil))
  end

  defp sort_by(repos, ""), do: repos

  defp sort_by(repos, sort) do
    sort_key = sort_to_atom(sort)

    Enum.sort(repos, &compare_repos(&1, &2, sort_key))
  end

  defp sort_to_atom("stars"), do: :stargazers_count
  defp sort_to_atom("forks"), do: :forks_count
  defp sort_to_atom("issues"), do: :open_issues_count

  defp compare_repos(repo1, repo2, key) do
    case Map.get(repo1, key) <= Map.get(repo2, key) do
      true ->
        true

      _ ->
        false
    end
  end

  defp order(repos, "desc"), do: Enum.reverse(repos)
  defp order(repos, _), do: repos

  defp name_filter_fn(repo, repo_name) do
    has_substr?(Map.get(repo, :name), repo_name)
  end

  defp language_filter_fn(repo, language) do
    equivalent_strings?(Map.get(repo, :language), language)
  end

  defp license_filter_fn(repo, license) do
    has_license?(Map.get(repo, :license), license)
  end

  defp get_filter_and_sort_values(filters_and_sort) do
    @filter_and_sort_keys
    |> Enum.map(fn filter_key -> Keyword.get(filters_and_sort, filter_key, "") end)
  end

  defp has_license?(nil, _license_key), do: false

  defp has_license?(license, license_key) do
    case Map.has_key?(license, :key) do
      true ->
        String.equivalent?(license.key, license_key)

      _ ->
        false
    end
  end

  defp has_substr?(name, substr) do
    String.contains?(String.downcase(name), String.downcase(substr))
  end

  defp equivalent_strings?(first_string, second_string)
       when is_binary(first_string) and is_binary(second_string) do
    String.equivalent?(String.downcase(first_string), String.downcase(second_string))
  end

  defp equivalent_strings?(_, _), do: false

  defp get_repositories(state) do
    Map.get(state, :repositories, [])
  end

  defp get_cache_config(state) do
    Map.take(state, [:cache_vsn, :cache_timeout])
  end

  defp update_query_params(state, new_query_params) do
    Map.put(state, :query_params, new_query_params)
  end

  defp update_cache_vsn(state) do
    Map.update(state, :cache_vsn, @cache_vsn, &(&1 + 1))
  end

  defp update_repositories(state, new_value) do
    Map.put(state, :repositories, new_value)
  end

  defp schedule_cache_cleanup(%{cache_vsn: vsn, cache_timeout: timeout}) do
    Process.send_after(self(), {:clean_cache, vsn}, timeout)
  end
end
