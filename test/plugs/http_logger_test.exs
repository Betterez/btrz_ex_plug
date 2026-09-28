defmodule BtrzExPlug.Plugs.HttpLoggerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias BtrzExPlug.Plugs.HttpLogger
  alias Plug.Conn

  setup do
    previous = Application.get_env(:btrz_ex_plug, :server_id)
    Application.put_env(:btrz_ex_plug, :server_id, "test-host")

    on_exit(fn ->
      if previous do
        Application.put_env(:btrz_ex_plug, :server_id, previous)
      else
        Application.delete_env(:btrz_ex_plug, :server_id)
      end
    end)

    :ok
  end

  test "logs req and res lines with service prefix and morgan fields" do
    opts = HttpLogger.init(service: "my_service")

    log =
      capture_log(fn ->
        conn =
          :get
          |> Plug.Test.conn("/webhooks?a=1")
          |> Conn.put_req_header("x-api-key", "secret")
          |> Conn.put_req_header("user-agent", "curl/8")
          |> Conn.put_req_header("x-amzn-trace-id", "Root=1-abc")
          |> HttpLogger.call(opts)
          |> Conn.send_resp(201, "ok")

        assert conn.status == 201
      end)

    assert log =~ "[my_service-req]"
    assert log =~ "[my_service-res]"
    assert log =~ ~s(server_id="test-host##{:os.getpid()}")
    assert log =~ ~s(xapikey="secret")
    assert log =~ ~s(url="/webhooks?a=1")
    assert log =~ ~s(amzn_trace_id="Root-1-abc")
    assert log =~ "method=GET"
    assert log =~ "status=201"
    assert log =~ "responselength=2"
    assert log =~ "responsetime="
    refute log =~ ~s(method="GET")
  end

  test "server_id option overrides application env" do
    opts = HttpLogger.init(service: "svc", server_id: "custom-id")

    log =
      capture_log(fn ->
        :get
        |> Plug.Test.conn("/")
        |> HttpLogger.call(opts)
        |> Conn.send_resp(200, "")
      end)

    assert log =~ ~s(server_id="custom-id##{:os.getpid()}")
  end

  test "server_id callbacks are ignored" do
    for server_id <- [fn -> "from-fun" end, {__MODULE__, :from_mfa, []}] do
      opts = HttpLogger.init(service: "svc", server_id: server_id)

      log =
        capture_log(fn ->
          :get
          |> Plug.Test.conn("/")
          |> HttpLogger.call(opts)
          |> Conn.send_resp(200, "")
        end)

      assert log =~ ~s(server_id="-##{:os.getpid()}")
      refute log =~ "from-fun"
      refute log =~ "from-mfa"
    end
  end

  def from_mfa do
    "from-mfa"
  end

  test "init requires service" do
    assert_raise KeyError, fn -> HttpLogger.init([]) end
  end
end
