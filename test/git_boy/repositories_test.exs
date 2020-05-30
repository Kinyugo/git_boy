defmodule GitBoy.RepositoriesTest do
  use ExUnit.Case, async: true
  alias GitBoy.Repositories

  @custom_query_params [query: ["language:javascript"], sort: "issues"]
  setup do
    {:ok, repo_server} = Repositories.start_link(cache_timeout: 2_000)

    %{repo_server: repo_server}
  end

  test "fetches default list of repositories when initialized", %{repo_server: repo_server} do
    assert Enum.count(Repositories.list_repositories(repo_server)) > 0
  end

  test "fetches repositories with the given params", %{repo_server: repo_server} do
    assert Enum.count(Repositories.fetch_repositories(repo_server, @custom_query_params))
  end

  test "cleans up cache after given timeout", %{repo_server: repo_server} do
    Repositories.fetch_repositories(repo_server, @custom_query_params)

    # Await the timeout to expire
    Process.sleep(3_000)

    assert Enum.count(Repositories.list_repositories(repo_server)) == 0
  end
end
