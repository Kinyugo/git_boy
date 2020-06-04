defmodule GitBoyWeb.RepositoryLive.RepoComponent do
  use GitBoyWeb, :live_component

  def render(assigns) do
    ~L"""
      <div class="repo">
        <div class="repo__header">
          <%= link @repo.name, to: @repo.url, class: "repo__name" %>

          <%= if @repo.fork do %>
            <img src="/images/forked.svg" alt="~forked" class="repo__forked">
          <% end %>
        </div>

        <div class="repo__body">
          <p class="repo__description">
            <%= @repo.description %>
          </p>
        </div>

        <div class="repo__footer">
          <%= if @repo.license do %>
            <div class="repo__metadata repo__metadata--license">
              <img src="/images/license.svg" class="repo__metadata-icon repo__metadata-icon--license">
              <%= @repo.license.name %>
            </div>
          <% end %>

          <div class="repo__metadata repo__metadata--forks">
            <img src="/images/forks.svg" alt="Forks: " class="repo__metadata-icon repo__metadata-icon--forks">
            <%= @repo.forks_count %>
          </div>

          <div class="repo__metadata repo__metadata--stars">
            <span class="material-icons repo__metadata-icon repo__metadata-icon--stars">
              star_rate
            </span>
            <%= @repo.stargazers_count %>
          </div>

          <%= if String.valid?(@repo.language) and String.length(@repo.language) > 0 do %>
            <div class="repo__metadata repo__metadata--language">
              <span class="repo__metadata-icon repo__metadata-icon--language" style="background-color: <%= string_to_hex_color(@repo.language) %>;">
              </span>
              <%= @repo.language %>
            </div>
          <% end %>

          <div class="repo__metadata repo__metadata--issues">
            <span  class="material-icons repo__metadata-icon repo__metadata-icon--issues">
              error_outline
            </span>
            <%= @repo.open_issues_count %>
          </div>
        </div>
      </div>
    """
  end

  defp string_to_hex_color(string) do
    case String.valid?(string) do
      true ->
        string
        |> String.graphemes()
        |> Enum.reduce(0, fn grapheme, acc ->
          <<v::utf8>> = grapheme
          acc + v + 180
        end)
        |> Integer.to_string(16)
        |> String.slice(0, 6)
        |> String.pad_trailing(6, "0")
        |> String.pad_leading(7, "#")

      _ ->
        ""
    end
  end
end
