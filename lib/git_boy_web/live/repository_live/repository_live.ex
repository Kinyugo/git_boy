defmodule GitBoyWeb.RepositoryLive do
  use GitBoyWeb, :live_view
  alias GitBoy.Repositories
  alias GitBoy.ProgrammingLanguages
  alias GitBoyWeb.RepositoryLive.RepoComponent
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    repo_assigns = get_repo_assigns(socket)

    default_assigns =
      [
        repo_name: "",
        language: "",
        language_suggestions: [],
        loading: false
      ] ++ repo_assigns

    socket = assign(socket, default_assigns)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_repos", %{"value" => repo_name_prefix} = params, socket) do
    Logger.info("Filtering repositories: #{inspect(params)}")

    repos = Repositories.filter_by_name(get_assigns(socket, :repo_server), repo_name_prefix)

    {:noreply, assign(socket, repos: repos)}
  end

  @impl true
  def handle_event(
        "search_repositories",
        %{"language" => language, "repo_name" => repo_name},
        socket
      ) do
    send(self(), {:search_repositories, [language: language, repo_name: repo_name]})

    {:noreply, assign(socket, repos: [], language: language, repo_name: repo_name, loading: true)}
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

    socket = assign(socket, language_suggestions: language_suggestion, repos: repos)

    Logger.info("Updating language suggestions: #{inspect(params)}")

    {:noreply, socket}
  end

  ## Info
  @impl true
  def handle_info({:search_repositories, [language: language, repo_name: repo_name]}, socket) do
    query_params = [query: [repo_name, "language:#{language}"]]

    repos = Repositories.fetch_repositories(get_assigns(socket, :repo_server), query_params)

    {:noreply, assign(socket, repos: repos, loading: false)}
  end

  ## Helpers
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
