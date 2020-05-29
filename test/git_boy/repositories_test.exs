defmodule GitBoy.RepositoriesTest do
  use ExUnit.Case, async: true
  alias GitBoy.Repositories.Repository

  @valid_repository_data %{
    "id" => 123,
    "full_name" => "test_repo",
    "description" => "just a test repo",
    "language" => "call it what you want",
    "html_url" => "nobodyknows.nobodycares",
    "fork" => false,
    "forks_count" => 40,
    "open_issues_count" => 30,
    "stargazers_count" => 100,
    "license" => %{
      "key" => "mit",
      "name" => "MIT License"
    }
  }
  @invalid_repository_data %{}

  describe "Repository.parse/1" do
    test "returns a Repository struct given valid attributes" do
      assert %Repository{} = Repository.parse(@valid_repository_data)
    end

    test "returns nil given invalid repository data" do
      assert nil == Repository.parse(@invalid_repository_data)
    end
  end
end
