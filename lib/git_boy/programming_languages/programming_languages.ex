defmodule GitBoy.ProgrammingLanguages do
  @moduledoc """
  GitBoy.ProgrammingLanguages module provides functions
  for suggesting a list of programming languages
  based on their prefix.

  It also provides functions that work with the wikipedia
  API in-order to fetch a comprehensive list of programming
  languages.

  It uses Agents internally to handle its state so it should
  be added to the list of children in `application.ex` like this:

  ```
  children = [
    # Other children
    ...
    GitBoy.ProgrammingLanguages,
    # Other children
    ...
  ]
  ```
  """
  use Agent

  @wikipedia_url "https://en.wikipedia.org/wiki/List_of_programming_languages"
  @language_element_selector ".div-col > ul > li > a"

  # Start the HTTP client
  Application.ensure_started(:httpoison)

  ## API

  # Called by the supervisor when starting the child
  def start_link(_opts) do
    Agent.start_link(fn -> fetch_languages_from_api() end, name: __MODULE__)
  end

  @doc """
  Suggests programming languages based on their prefix.

  ## Examples

      iex> suggest_languages("")
      []
      iex> suggest_languages("elix")
      ["Elixir"]
  """
  @spec suggest_languages(String.t()) :: [String.t()] | []
  def suggest_languages(""), do: []

  def suggest_languages(language_prefix) do
    list_languages()
    |> Enum.filter(&has_prefix?(&1, language_prefix))
  end

  defp has_prefix?(language, language_prefix) do
    String.starts_with?(String.downcase(language), String.downcase(language_prefix))
  end

  @doc """
  Lists all programming languages available from wikipedia: #{@wikipedia_url}

  ## Examples

      iex> list_languages()
      ["A# .NET", "Elixir", ...]
  """
  @spec list_languages() :: [String.t()] | []
  def list_languages(), do: Agent.get(__MODULE__, & &1)

  ## Helper functions
  defp fetch_languages_from_api() do
    @wikipedia_url
    |> HTTPoison.get()
    |> parse_api_response()
  end

  defp parse_api_response({:error, _error}), do: []

  defp parse_api_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    case Floki.parse_document(body) do
      {:ok, html} -> extract_languages(html)
      {:error, _reason} -> []
    end
  end

  defp parse_api_response({:ok, %HTTPoison.Response{status_code: _status_code}}), do: []

  defp extract_languages(html) do
    html
    |> Floki.find(@language_element_selector)
    |> Enum.map(&extract_text_from_tree/1)
  end

  defp extract_text_from_tree({_name, _attrs, [text]}), do: text
  defp extract_text_from_tree(_html_tree), do: nil
end
