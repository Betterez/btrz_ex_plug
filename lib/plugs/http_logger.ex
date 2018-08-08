defmodule BtrzExPlug.Plugs.HttpLogger do
  @moduledoc """
  HTTP logs for the Betterez apps.

  Uses the Logster Plug (https://github.com/navinpeiris/logster) with additional fields and renaming in order to log the same for all the HTTP apps.

  To use it, just plug it into the desired module:
      plug BtrzExPlug.Plugs.HttpLogger

  """
  use Plug.Builder

  plug(:additional_fields)
  plug(Logster.Plugs.Logger, renames: %{duration: :responsetime, path: :url})

  @doc false
  @spec additional_fields(Plug.Conn.t(), nil | keyword()) :: Plug.Conn.t()
  defp additional_fields(conn, _opts) do
    Logger.metadata(
      remoteaddr: to_string(:inet_parse.ntoa(conn.remote_ip)),
      xapikey: get_head_or_empty(Plug.Conn.get_req_header(conn, "x-api-key")),
      date: DateTime.utc_now() |> DateTime.to_iso8601(),
      traceId: get_head_or_empty(Plug.Conn.get_req_header(conn, "x-amzn-trace-id")),
      http: "1.1",
      responselength: get_head_or_empty(Plug.Conn.get_resp_header(conn, "content-length")),
      referrer: get_head_or_empty(Plug.Conn.get_req_header(conn, "referer")),
      useragent: get_head_or_empty(Plug.Conn.get_req_header(conn, "user-agent"))
    )

    conn
  end

  @doc false
  defp get_head_or_empty([header]) do
    header
  end

  defp get_head_or_empty(_) do
    "-"
  end
end
