defmodule BtrzExPlug.ApplicationLogFormatterTest do
  use ExUnit.Case, async: false

  alias BtrzExPlug.ApplicationLogFormatter

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

  test "formats uppercase level, date, server_id, traces and message" do
    line =
      ApplicationLogFormatter.format(
        :info,
        "hello",
        {{2026, 1, 1}, {12, 0, 0, 123}},
        amzn_trace_id: "Root=1",
        otel_trace_id: "4bf92f3577b34da6a3ce929d0e0e4736"
      )
      |> IO.iodata_to_binary()

    assert String.starts_with?(line, "INFO  2026-01-01T12:00:00.123Z ")
    assert line =~ "test-host##{:os.getpid()}"
    assert line =~ " Root-1 "
    assert line =~ " 4bf92f3577b34da6a3ce929d0e0e4736 "
    assert String.ends_with?(line, "hello\n")
  end

  test "falls back to dash when trace metadata is missing" do
    line =
      ApplicationLogFormatter.format(:error, "boom", {{2026, 1, 1}, {12, 0, 0, 0}}, [])
      |> IO.iodata_to_binary()

    assert String.starts_with?(line, "ERROR 2026-01-01T12:00:00.000Z ")
    assert line =~ " - - boom\n"
  end
end
