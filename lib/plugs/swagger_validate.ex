defmodule BtrzExPlug.Plugs.SwaggerValidate do
  @moduledoc """
  A plug to automatically validate all requests in a given scope. Please make
  sure to:
  * load Swagger specs at application start with
    `PhoenixSwagger.Validator.parse_swagger_schema/1`
  * set `conn.private.phoenix_swagger.valid` to `true` to skip validation
  """
  import Plug.Conn
  alias PhoenixSwagger.ConnValidator

  @doc """
  Plug.init callback
  Options:
   - `:validation_failed_status` the response status to set when parameter validation fails, defaults to 400.
  """
  def init(opts) do
    opts
  end

  def call(conn, opts) do
    conn
    |> ConnValidator.validate()
    |> send_response(conn, opts)
  end

  def send_response({:ok, _}, conn, _opts) do
    conn
    |> put_private(:phoenix_swagger, %{valid: true})
  end

  def send_response({:error, :no_matching_path}, conn, _opts) do
    send_error_response(conn, 404, "API does not provide resource")
  end

  def send_response({:error, [{message, _path} | _]}, conn, opts) do
    validation_failed_status = Keyword.get(opts, :validation_failed_status, 400)
    send_error_response(conn, validation_failed_status, message)
  end

  def send_response({:error, message, _path}, conn, opts) do
    validation_failed_status = Keyword.get(opts, :validation_failed_status, 400)
    send_error_response(conn, validation_failed_status, message)
  end

  defp send_error_response(conn, status, message) do
    response = %{
      status: 400,
      code: "WRONG_DATA",
      message: message
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Poison.encode!(response))
    |> halt()
  end
end
