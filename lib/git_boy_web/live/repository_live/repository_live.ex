defmodule GitBoyWeb.RepositoryLive do
  use GitBoyWeb, :live_view
  alias GitBoyWeb.RepositoryLive.RepoComponent
  alias GitBoy.Repositories
  alias GitBoy.Licenses
  alias GitBoy.ProgrammingLanguages
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    Logger.debug("Running mount in process: #{inspect(self())}")

    {repo_server, default_repos} = setup_repo_server(socket)
    common_licenses = Licenses.list_licenses()

    default_assigns = [
      repo_server: repo_server,
      repos: default_repos,
      common_licenses: common_licenses,
      language_suggestions: [],
      repo_name: "",
      language: "",
      license: "",
      sort_order: "",
      loading: false
    ]

    socket = assign(socket, default_assigns)

    {:ok, socket, temporary_assigns: [repos: nil, language_suggestions: []]}
  end

  defp setup_repo_server(socket) do
    case connected?(socket) do
      true ->
        # Start repo server
        {:ok, repo_server} = Repositories.start_link([])
        # Fetch default list of repositories
        default_repos = Repositories.fetch_repositories(repo_server)

        {repo_server, default_repos}

      false ->
        {nil, []}
    end
  end

  @impl true
  def handle_event("search_repositories", params, socket) do
    %{
      "language" => language,
      "repo_name" => repo_name,
      "license" => license,
      "sort_order" => sort_order
    } = params

    attrs = [
      repos: [],
      loading: true,
      language: language,
      repo_name: repo_name,
      license: license,
      sort_order: sort_order
    ]

    send(
      self(),
      {:search_repositories, Keyword.take(attrs, [:language, :repo_name, :license, :sort_order])}
    )

    {:noreply, assign(socket, attrs)}
  end

  @impl true
  def handle_event("update_language_suggestions", %{"value" => language_prefix}, socket) do
    repos =
      socket
      |> get_repo_server()
      |> Repositories.filter_by_language(language_prefix)

    language_suggestions = ProgrammingLanguages.suggest_languages(language_prefix)

    attrs = [language_suggestions: language_suggestions, repos: repos, language: language_prefix]

    {:noreply, assign(socket, attrs)}
  end

  @impl true
  def handle_event("filter_repos_by_name", %{"value" => name_prefix}, socket) do
    repos =
      socket
      |> get_repo_server()
      |> Repositories.filter_by_name(name_prefix)

    attrs = [repos: repos, repo_name: name_prefix]

    {:noreply, assign(socket, attrs)}
  end

  @impl true
  def handle_event("filter_repos_by_license", %{"value" => license}, socket) do
    repos =
      socket
      |> get_repo_server()
      |> Repositories.filter_by_license(license)

    attrs = [repos: repos, license: license]

    {:noreply, assign(socket, attrs)}
  end

  @impl true
  def handle_event("sort_repos", %{"value" => sort_order}, socket) do
    [sort_by, order] = parse_sort_order(sort_order)

    repos =
      socket
      |> get_repo_server()
      |> Repositories.sort_repos(sort_by, order)

    attrs = [repos: repos, sort_order: sort_order]

    {:noreply, assign(socket, attrs)}
  end

  @impl true
  def handle_event("filter_and_sort_repos", _params, socket) do
    language = get_assigns(socket, :language)
    repo_name = get_assigns(socket, :repo_name)
    license = get_assigns(socket, :license)
    sort_order = get_assigns(socket, :sort_order)

    [sort_by, order] = parse_sort_order(sort_order)

    filters = [
      language: language,
      repo_name: repo_name,
      license: license,
      sort: sort_by,
      order: order
    ]

    repos =
      socket
      |> get_repo_server()
      |> Repositories.filter_and_sort(filters)

    attrs = [repos: repos]

    {:noreply, assign(socket, attrs)}
  end

  @impl true
  def handle_info({:search_repositories, params}, socket) do
    [language, repo_name, license, sort_order] = Keyword.values(params)

    [sort_by, order] = parse_sort_order(sort_order)
    query = [repo_name, "language:#{language}", "license:#{license}"]

    query_params = [
      query: query,
      sort: sort_by,
      order: order
    ]

    repos =
      socket
      |> get_repo_server()
      |> Repositories.fetch_repositories(query_params)

    {:noreply, assign(socket, repos: repos, loading: false)}
  end

  defp parse_sort_order(""), do: ["", ""]

  defp parse_sort_order(sort_order) do
    sort_order
    |> String.split()
    |> Enum.slice(0, 2)
  end

  defp get_repo_server(socket), do: get_assigns(socket, :repo_server)
  defp get_assigns(socket, key), do: Map.get(socket.assigns, key)

  def list_licenses(nil, common_licenses) do
    Enum.map(common_licenses, fn license -> [license: license, in_repo_licenses?: false] end)
  end

  def list_licenses(repo_server, common_licenses) do
    repo_licenses = Repositories.list_licenses(repo_server)

    repo_licenses
    |> Enum.concat(repo_licenses)
    |> Enum.concat(common_licenses)
    |> Enum.uniq()
    |> Enum.map(fn license ->
      if Enum.member?(repo_licenses, license) do
        [license: license, in_repo_licenses?: true]
      else
        [license: license, in_repo_licenses?: false]
      end
    end)
  end

  def render_license_option(assigns, selected_license) do
    assigns = Enum.into(assigns, %{})

    ~L"""
      <option
      value="<%= @license.key %>"
      class = "repositories__license__option <%= if @in_repo_licenses?, do: 'repositories__license__option--in-licenses' %>"
      <%= if @license.key == selected_license, do: "selected" %>
      >
        <%= @license.name %>
      </option>
    """
  end

  def sort_options() do
    [
      "Sort By": "",
      "Stars Ascending": "stars asc",
      "Stars Descending": "stars desc",
      "Forks Ascending": "forks asc",
      "Forks Descending": "forks desc",
      "Issues Ascending": "issues asc",
      "Issues Descending": "issues desc"
    ]
  end
end
