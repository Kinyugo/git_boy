defmodule GitBoyWeb.LayoutView do
  use GitBoyWeb, :view

  @spec get_nav_link_classes(map, String.t()) :: binary
  def get_nav_link_classes(conn, routes_to) do
    default_classes = ["nav__item__link"]

    classes =
      if get_active_route(conn) == routes_to do
        ["nav__item__link--active" | default_classes]
      else
        default_classes
      end

    Enum.join(classes, " ")
  end

  defp get_active_route(conn) do
    conn
    |> Map.get(:request_path)
    |> String.split(~r/\//)
    |> Enum.at(1)
  end
end
