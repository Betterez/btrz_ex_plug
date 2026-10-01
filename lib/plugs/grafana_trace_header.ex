defmodule BtrzExPlug.Plugs.GrafanaTraceHeader do
  @moduledoc """
  Puts `x-grafana-trace-id` on the response from `conn.assigns.otel_trace_id`.

  Place after `BtrzExPlug.Plugs.HttpLogger`, which assigns `:otel_trace_id`.
  """
  @behaviour Plug

  alias Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case Map.get(conn.assigns, :otel_trace_id) do
      id when is_binary(id) and id != "" and id != "-" ->
        Conn.put_resp_header(conn, "x-grafana-trace-id", id)

      _ ->
        conn
    end
  end
end
