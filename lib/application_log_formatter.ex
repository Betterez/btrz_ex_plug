defmodule BtrzExPlug.ApplicationLogFormatter do
  @moduledoc false

  def format(level, message, timestamp, metadata) do
    level_str =
      level
      |> to_string()
      |> String.upcase()
      |> String.pad_trailing(5)

    server_id =
      "#{server_id_base()}##{:os.getpid()}"
      |> String.pad_trailing(15)

    amzn_trace_id = sanitize_amzn(metadata_value(metadata, :amzn_trace_id))
    otel_trace_id = metadata_value(metadata, :otel_trace_id)

    [
      level_str,
      ?\s,
      format_date(timestamp),
      ?\s,
      server_id,
      ?\s,
      amzn_trace_id,
      ?\s,
      otel_trace_id,
      ?\s,
      message,
      ?\n
    ]
  end

  defp format_date({{y, m, d}, {h, min, s, ms}}) do
    :io_lib.format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0B.~3..0BZ", [y, m, d, h, min, s, ms])
  end

  defp server_id_base do
    case Application.get_env(:btrz_ex_plug, :server_id, "-") do
      value when is_binary(value) and value != "" -> value
      _ -> "-"
    end
  end

  defp metadata_value(metadata, key) do
    case Keyword.get(metadata, key) do
      value when is_binary(value) and value != "" -> value
      _ -> "-"
    end
  end

  defp sanitize_amzn("-"), do: "-"

  defp sanitize_amzn(value) do
    String.replace(value, "=", "-", global: false)
  end
end
