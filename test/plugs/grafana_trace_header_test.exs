defmodule BtrzExPlug.Plugs.GrafanaTraceHeaderTest do
  use ExUnit.Case, async: false

  alias BtrzExPlug.Plugs.GrafanaTraceHeader
  alias Plug.Conn

  test "sets x-grafana-trace-id from assigns.otel_trace_id" do
    opts = GrafanaTraceHeader.init([])

    conn =
      :get
      |> Plug.Test.conn("/")
      |> Conn.assign(:otel_trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
      |> GrafanaTraceHeader.call(opts)
      |> Conn.send_resp(200, "ok")

    assert Conn.get_resp_header(conn, "x-grafana-trace-id") == [
             "4bf92f3577b34da6a3ce929d0e0e4736"
           ]
  end

  test "does not set header when otel_trace_id is dash" do
    opts = GrafanaTraceHeader.init([])

    conn =
      :get
      |> Plug.Test.conn("/")
      |> Conn.assign(:otel_trace_id, "-")
      |> GrafanaTraceHeader.call(opts)
      |> Conn.send_resp(200, "ok")

    assert Conn.get_resp_header(conn, "x-grafana-trace-id") == []
  end

  test "does not set header when otel_trace_id assign is missing" do
    opts = GrafanaTraceHeader.init([])

    conn =
      :get
      |> Plug.Test.conn("/")
      |> GrafanaTraceHeader.call(opts)
      |> Conn.send_resp(200, "ok")

    assert Conn.get_resp_header(conn, "x-grafana-trace-id") == []
  end
end
