defmodule BtrzExPlug.HttpLogFormatterTest do
  use ExUnit.Case, async: true

  alias BtrzExPlug.HttpLogFormatter

  test "quotes allowlisted binary fields and leaves method/http unquoted" do
    iodata =
      HttpLogFormatter.format(
        server_id: "localhost#1",
        remoteaddr: "127.0.0.1",
        method: "GET",
        url: "/health",
        http: "1.1",
        status: 200,
        responsetime: 12.34
      )

    line = iodata |> IO.iodata_to_binary()

    assert line =~ ~s(server_id="localhost#1")
    assert line =~ ~s(remoteaddr="127.0.0.1")
    assert line =~ ~s(url="/health")
    assert line =~ "method=GET"
    assert line =~ "http=1.1"
    assert line =~ "status=200"
    assert line =~ "responsetime=12.3"
    refute line =~ ~s(method="GET")
  end

  test "escapes quotes, backslashes, and newlines in quoted fields" do
    line =
      [url: "a\"b\\c\nd\re", method: "GET"]
      |> HttpLogFormatter.format()
      |> IO.iodata_to_binary()

    assert line == ~S(url="a\"b\\c\nd\re" method=GET)
  end

  test "nil and unexpected values fall back to dash" do
    line =
      [status: nil, method: %{oops: true}]
      |> HttpLogFormatter.format()
      |> IO.iodata_to_binary()

    assert line == "status=- method=-"
  end

  test "otel_trace_id is emitted as grafana_trace_id for log parsers" do
    line =
      [otel_trace_id: "4bf92f3577b34da6a3ce929d0e0e4736", method: "GET"]
      |> HttpLogFormatter.format()
      |> IO.iodata_to_binary()

    assert line == ~s(grafana_trace_id="4bf92f3577b34da6a3ce929d0e0e4736" method=GET)
    refute line =~ ~r/(^|\s)otel_trace_id=/
  end
end
