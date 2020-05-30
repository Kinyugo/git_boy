defmodule GitBoy.Repositories.Repository do
  alias GitBoy.Licenses.License
  alias GitBoy.Repositories.Repository

  @enforce_keys [:id, :name, :description, :language, :url, :fork]
  defstruct [
    :id,
    :name,
    :description,
    :language,
    :url,
    :fork,
    :forks_count,
    :open_issues_count,
    :stargazers_count,
    :license
  ]

  @typedoc """
  Type that represents the Repository struct with `id` as integer,
  `name` as String, `description` as String, `language` as String,
  `fork` as boolean, `forks_count` as integer, `open_issues_count` as integer,
  `stargazers_count` as integer and `license` maybe of License type or nil.
  """
  @type t() :: %Repository{
          id: integer(),
          name: String.t(),
          description: String.t(),
          language: String.t(),
          url: String.t(),
          fork: boolean(),
          forks_count: integer(),
          open_issues_count: integer(),
          stargazers_count: integer(),
          license: License.t() | nil
        }

  # Keys that must be part of the data-structure to be parsed into a Repository
  @expected_keys ~w(
    id full_name html_url language description forks_count fork open_issues_count
    license stargazers_count
    )

  @spec parse(map()) :: Repository.t() | nil
  def parse(repository_data) do
    case has_all_required_keys?(repository_data) do
      true -> transform_to_struct(repository_data)
      _ -> nil
    end
  end

  defp has_all_required_keys?(repository_data) do
    Enum.all?(@expected_keys, fn expected_key -> Map.has_key?(repository_data, expected_key) end)
  end

  defp transform_to_struct(repository_data) do
    fields =
      Enum.into(@expected_keys, [], fn expected_key ->
        transform_to_tuple(expected_key, Map.get(repository_data, expected_key))
      end)

    struct!(__MODULE__, fields)
  end

  defp transform_to_tuple("full_name", full_name), do: {:name, full_name}
  defp transform_to_tuple("html_url", html_url), do: {:url, html_url}
  defp transform_to_tuple("license", license_data), do: {:license, License.parse(license_data)}
  defp transform_to_tuple(key, value), do: {String.to_atom(key), value}
end

defimpl String.Chars, for: GitBoy.Repositories.Repository do
  def to_string(term) do
    inspect(term)
  end
end
