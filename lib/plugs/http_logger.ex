defmodule BtrzExPlug.Plugs.HttpLogger do
  @moduledoc """
  HTTP req/res activity logger.

  Requires `:service`.

      plug BtrzExPlug.Plugs.HttpLogger, service: "service-name"

  Set the server id once at boot:

      Application.put_env(:btrz_ex_plug, :server_id, instance_id)

  Consumers must wire OpenTelemetry (SDK + cowboy/phoenix instrumentation) and
  place `Plug.Telemetry, event_prefix: [:phoenix, :endpoint]` **before** this plug
  so the request process has the server span when logging starts.

  To expose the trace id on the response, also plug
  `BtrzExPlug.Plugs.GrafanaTraceHeader` **after** this one.

  HTTP lines carry `log_type: :http` metadata. Route them to their own file
  and keep them out of the application log:

      config :logger, utc_log: true

      config :logger, :application,
        metadata_reject: [log_type: :http],
        format: {BtrzExPlug.ApplicationLogFormatter, :format},
        metadata: [:amzn_trace_id, :otel_trace_id]

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
    amzn_raw = amzn_trace_id_raw(conn)
    otel_trace_id = current_otel_trace_id()

    conn =
      conn
      |> Conn.assign(:amzn_trace_id, amzn_raw)
      |> Conn.assign(:otel_trace_id, otel_trace_id)

    maybe_set_amzn_span_attribute(amzn_raw)

    req_fields = req_fields(conn, opts)

    Logger.metadata(
      server_id: req_fields[:server_id],
      remoteaddr: req_fields[:remoteaddr],
      xapikey: req_fields[:xapikey],
      amzn_trace_id: amzn_raw
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
      amzn_trace_id: sanitize_amzn(conn.assigns.amzn_trace_id),
      otel_trace_id: conn.assigns.otel_trace_id,
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
      amzn_trace_id: sanitize_amzn(conn.assigns.amzn_trace_id),
      otel_trace_id: conn.assigns.otel_trace_id,
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

  defp current_otel_trace_id do
    span_ctx = OpenTelemetry.Tracer.current_span_ctx()

    cond do
      span_ctx == :undefined ->
        "-"

      not OpenTelemetry.Span.is_valid(span_ctx) ->
        "-"

      true ->
        id =
          span_ctx
          |> OpenTelemetry.Span.hex_trace_id()
          |> to_string()

        if id == "" or id == String.duplicate("0", 32) do
          "-"
        else
          id
        end
    end
  end

  defp maybe_set_amzn_span_attribute("-"), do: :ok

  defp maybe_set_amzn_span_attribute(amzn_raw) do
    OpenTelemetry.Tracer.set_attributes(%{"aws.xray.trace_id" => amzn_raw})
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

  defp amzn_trace_id_raw(conn) do
    case Plug.Conn.get_req_header(conn, "x-amzn-trace-id") do
      [value] when value != "" -> value
      _ -> "-"
    end
  end

  defp sanitize_amzn("-"), do: "-"

  defp sanitize_amzn(value) do
    String.replace(value, "=", "-", global: false)
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
