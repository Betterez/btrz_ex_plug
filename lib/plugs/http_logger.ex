defmodule BtrzExPlug.Plugs.HttpLogger do
  @moduledoc """
  HTTP req/res activity logger.

  Requires `:service`.

      plug BtrzExPlug.Plugs.HttpLogger, service: "service-name"

  Set the server id once at boot:

      Application.put_env(:btrz_ex_plug, :server_id, instance_id)

  HTTP lines carry `log_type: :http` metadata. Route them to their own file
  and keep them out of the application log:

      config :logger, utc_log: true

      config :logger, :application,
        metadata_reject: [log_type: :http],
        format: {BtrzExPlug.ApplicationLogFormatter, :format},
        metadata: [:amzn_trace_id, :grafana_trace_id]

      config :logger, :http_activity,
        metadata_filter: [log_type: :http],
        format: "$message\\n",
        metadata: []
  """
  @behaviour Plug

  require Logger
  alias Plug.Conn
  alias BtrzExPlug.HttpLogFormatter

  def init(opts) do
    service = Keyword.fetch!(opts, :service)

    %{
      service: to_string(service),
      server_id: Keyword.get(opts, :server_id)
    }
  end

  def call(conn, opts) do
    start_time = :erlang.monotonic_time()
    req_fields = req_fields(conn, opts)

    Logger.metadata(
      server_id: req_fields[:server_id],
      remoteaddr: req_fields[:remoteaddr],
      xapikey: req_fields[:xapikey],
      amzn_trace_id: req_fields[:amzn_trace_id],
      grafana_trace_id: req_fields[:grafana_trace_id]
    )

    log_http(opts.service, "req", req_fields)

    Conn.register_before_send(conn, fn conn ->
      stop_time = :erlang.monotonic_time()

      duration_ms =
        (stop_time - start_time)
        |> :erlang.convert_time_unit(:native, :micro_seconds)
        |> Kernel./(1000)

      log_http(opts.service, "res", res_fields(conn, opts, duration_ms))
      conn
    end)
  end

  defp req_fields(conn, opts) do
    [
      server_id: server_id(opts),
      remoteaddr: remoteaddr(conn),
      xapikey: header_or_dash(conn, "x-api-key"),
      date: log_date(),
      amzn_trace_id: amzn_trace_id(conn),
      grafana_trace_id: grafana_trace_id(conn),
      method: conn.method,
      url: request_url(conn),
      http: "1.1",
      referrer: header_or_dash(conn, "referer"),
      useragent: header_or_dash(conn, "user-agent")
    ]
  end

  defp res_fields(conn, opts, duration_ms) do
    [
      server_id: server_id(opts),
      remoteaddr: remoteaddr(conn),
      xapikey: header_or_dash(conn, "x-api-key"),
      responsetime: duration_ms,
      date: log_date(),
      amzn_trace_id: amzn_trace_id(conn),
      grafana_trace_id: grafana_trace_id(conn),
      method: conn.method,
      url: request_url(conn),
      http: "1.1",
      status: conn.status,
      responselength: response_length(conn),
      referrer: header_or_dash(conn, "referer"),
      useragent: header_or_dash(conn, "user-agent")
    ]
  end

  defp log_http(service, kind, fields) do
    Logger.log(
      :info,
      fn -> ["[", service, "-", kind, "] ", HttpLogFormatter.format(fields)] end,
      log_type: :http
    )
  end

  defp server_id(%{server_id: server_id}) do
    base = resolve_server_id(server_id)
    "#{base}##{:os.getpid()}"
  end

  defp resolve_server_id(nil), do: env_server_id()
  defp resolve_server_id(id) when is_binary(id) and id != "", do: id
  defp resolve_server_id(_), do: "-"

  defp env_server_id do
    case Application.get_env(:btrz_ex_plug, :server_id, "-") do
      id when is_binary(id) and id != "" -> id
      _ -> "-"
    end
  end

  defp remoteaddr(conn) do
    to_string(:inet_parse.ntoa(conn.remote_ip))
  end

  defp amzn_trace_id(conn) do
    case Plug.Conn.get_req_header(conn, "x-amzn-trace-id") do
      [value] -> String.replace(value, "=", "-", global: false)
      _ -> "-"
    end
  end

  defp grafana_trace_id(conn) do
    case Plug.Conn.get_req_header(conn, "x-grafana-trace-id") do
      [value] -> String.replace(value, "=", "-", global: false)
      _ -> "-"
    end
  end

  defp log_date do
    DateTime.utc_now()
    |> DateTime.truncate(:millisecond)
    |> DateTime.to_iso8601()
  end

  defp header_or_dash(conn, header) do
    case Plug.Conn.get_req_header(conn, header) do
      [value] -> value
      _ -> "-"
    end
  end

  defp request_url(%{request_path: path, query_string: ""}), do: path
  defp request_url(%{request_path: path, query_string: qs}), do: path <> "?" <> qs

  defp response_length(%Plug.Conn{resp_body: body}) when is_binary(body), do: byte_size(body)
  defp response_length(%Plug.Conn{resp_body: body}) when is_list(body), do: IO.iodata_length(body)

  defp response_length(conn) do
    case Plug.Conn.get_resp_header(conn, "content-length") do
      [len] -> len
      _ -> "-"
    end
  end
end
