defmodule BtrzExPlug.HttpLogFormatter do
  @moduledoc false

  @quoted_keys [
    :server_id,
    :remoteaddr,
    :xapikey,
    :date,
    :amzn_trace_id,
    :grafana_trace_id,
    :url,
    :referrer,
    :useragent
  ]

  def format(fields) do
    fields
    |> Enum.map(&format_field/1)
    |> Enum.intersperse(?\s)
  end

  defp format_field({key, value}) do
    [to_string(key), "=", format_value(key, value)]
  end

  defp format_value(_key, nil), do: "-"

  defp format_value(key, value) when is_binary(value) do
    if key in @quoted_keys do
      [?", escape_quoted(value), ?"]
    else
      value
    end
  end

  defp format_value(_key, value) when is_float(value) do
    :erlang.float_to_binary(value, decimals: 1)
  end

  defp format_value(_key, value) when is_atom(value) or is_integer(value) do
    to_string(value)
  end

  defp format_value(_key, _value), do: "-"

  defp escape_quoted(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
  end
end
