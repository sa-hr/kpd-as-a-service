defmodule KPD.Api.Controllers.SystemController do
  @moduledoc """
  Controller for system-level endpoints.

  Handles health checks, statistics, and API documentation.
  """

  import Plug.Conn
  alias KPD.Api.Helpers

  @doc """
  Returns health check status.
  """
  def health(conn) do
    Helpers.json_response(conn, 200, %{status: "ok"})
  end

  @doc """
  Returns statistics about the product classification database.
  """
  def stats(conn) do
    stats = %{
      total: KPD.count(),
      by_level: %{
        level_1_sections: KPD.count(level: 1),
        level_2_divisions: KPD.count(level: 2),
        level_3_groups: KPD.count(level: 3),
        level_4_classes: KPD.count(level: 4),
        level_5_categories: KPD.count(level: 5),
        level_6_subcategories: KPD.count(level: 6)
      }
    }

    Helpers.json_response(conn, 200, stats)
  end

  @doc """
  Serves the OpenAPI specification.
  """
  def openapi(conn) do
    openapi_path = Application.app_dir(:kpd, "priv/openapi.yaml")

    case File.read(openapi_path) do
      {:ok, content} ->
        conn
        |> put_resp_content_type("application/x-yaml")
        |> send_resp(200, content)

      {:error, _} ->
        Helpers.json_response(conn, 404, %{error: "OpenAPI specification not found"})
    end
  end
end
