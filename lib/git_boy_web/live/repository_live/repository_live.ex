defmodule GitBoyWeb.RepositoryLive do
  use GitBoyWeb, :live_view
  alias GitBoy.Repositories
  alias GitBoy.ProgrammingLanguages
  alias GitBoy.Licenses
  alias GitBoy.Licenses.License
  alias GitBoyWeb.RepositoryLive.RepoComponent
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    repo_assigns = get_repo_assigns(socket)

    common_licenses = Licenses.list_licenses()

    default_assigns =
      [
        repo_name: "",
        language: "",
        language_suggestions: [],
        license: "",
        sort: "",
        common_licenses: common_licenses,
        loading: false
      ] ++ repo_assigns

    socket = assign(socket, default_assigns)

    {:ok, socket, temporary_assigns: [repos: [], language_suggestions: []]}
  end

  @impl true
  def handle_event("apply_all_filters", _params, socket) do
    language = get_assigns(socket, :language)
    repo_name = get_assigns(socket, :repo_name)
    license = get_assigns(socket, :license)
    sort_order = get_assigns(socket, :sort)

    [sort_by, order] = parse_sort(sort_order)

    filters = [
      language: language,
      repo_name: repo_name,
      license: license,
      sort: sort_by,
      order: order
    ]

    Logger.info("Apply multiple filters to repos: #{inspect(filters)}")

    repos = Repositories.apply_all_filters(get_assigns(socket, :repo_server), filters)

    {:noreply, assign(socket, repos: repos)}
  end

  @impl true
  def handle_event("sort_repos", %{"value" => sort_order}, socket) do
    Logger.info("Sorting repositories by: #{inspect(sort_order)}")

    [sort_by, order] = parse_sort(sort_order)

    sorted_repos = Repositories.sort_repos(get_assigns(socket, :repo_server), sort_by, order)

    {:noreply, assign(socket, repos: sorted_repos, sort: sort_order)}
  end

  @impl true
  def handle_event("filter_repos_by_license", %{"value" => license_key} = params, socket) do
    Logger.info("Filtering repositories by license: #{inspect(params)}")

    repos = Repositories.filter_by_license(get_assigns(socket, :repo_server), license_key)

    {:noreply, assign(socket, repos: repos, license: license_key)}
  end

  @impl true
  def handle_event("filter_repos_by_name", %{"value" => repo_name_prefix} = params, socket) do
    Logger.info("Filtering repositories by name: #{inspect(params)}")

    repos = Repositories.filter_by_name(get_assigns(socket, :repo_server), repo_name_prefix)

    {:noreply, assign(socket, repos: repos, repo_name: repo_name_prefix)}
  end

  @impl true
  def handle_event(
        "search_repositories",
        %{"language" => language, "repo_name" => repo_name, "license" => license, "sort" => sort},
        socket
      ) do
    send(
      self(),
      {:search_repositories,
       [language: language, repo_name: repo_name, license: license, sort: sort]}
    )

    {:noreply,
     assign(socket,
       repos: [],
       language: language,
       repo_name: repo_name,
       license: license,
       sort: sort,
       loading: true
     )}
  end

  @impl true
  def handle_event(
        "update_assigns",
        %{"language" => language, "repo_name" => repo_name} = params,
        socket
      ) do
    Logger.info("Updating assigns: #{inspect(params)}")
    {:noreply, assign(socket, language: language, repo_name: repo_name)}
  end

  @impl true
  def handle_event(
        "update_language_suggestions_and_filter_repos",
        %{"value" => language_prefix} = params,
        socket
      ) do
    repos = Repositories.filter_by_language(get_assigns(socket, :repo_server), language_prefix)
    language_suggestion = ProgrammingLanguages.suggest_languages(language_prefix)

    socket =
      assign(socket,
        language_suggestions: language_suggestion,
        repos: repos,
        language: language_prefix
      )

    Logger.info("Updating language suggestions: #{inspect(params)}")

    {:noreply, socket}
  end

  ## Info
  @impl true
  def handle_info(
        {:search_repositories,
         [language: language, repo_name: repo_name, license: license, sort: sort]},
        socket
      ) do
    [sort_by, order] = parse_sort(sort)

    query_params = [
      query: [repo_name, "language:#{language}", "license:#{license}"],
      sort: sort_by,
      order: order
    ]

    repos = Repositories.fetch_repositories(get_assigns(socket, :repo_server), query_params)

    {:noreply, assign(socket, repos: repos, loading: false)}
  end

  ## Helpers
  defp parse_sort(""), do: ["", ""]

  defp parse_sort(sort) do
    sort
    |> String.split()
  end

  def sort_options do
    [
      "Sort By...": "",
      "Stars Ascending": "stars asc",
      "Stars Desending": "stars desc",
      "Forks Ascending": "forks asc",
      "Forks Descending": "forks desc",
      "Issues Ascending": "issues asc",
      "Issues Descending": "issues desc"
    ]
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

  defp get_assigns(socket, key), do: Map.get(socket.assigns, key)

  defp get_repo_assigns(socket) do
    if connected?(socket) do
      # Start repositories server
      {:ok, repo_server} = Repositories.start_link([])
      # Fetch default list of repositories
      repos = Repositories.fetch_repositories(repo_server)

      [repo_server: repo_server, repos: repos]
    else
      [
        repo_server: nil,
        repos: []
      ]
    end
  end
end
