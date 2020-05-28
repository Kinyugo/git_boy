defmodule GitBoy.Licenses.License do
  alias GitBoy.Licenses.License

  defstruct key: nil, name: nil

  @typedoc """
    Type that represents License struct with `:key` as String and `:name` as String
  """
  @type t() :: %License{key: String.t(), name: String.t()}

  @spec parse(map()) :: License.t() | nil
  def parse(%{"key" => key, "name" => name}) do
    license_fields = [key: key, name: name]

    struct!(__MODULE__, license_fields)
  end

  def parse(_invalid_map), do: nil
end
