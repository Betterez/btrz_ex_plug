defmodule BtrzExPlug.Plugs.SwaggerValidate do
  @moduledoc """
  A plug to automatically validate all requests in a given scope. Please make
  sure to:
  * load Swagger specs at appliction start with
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

  def call(%Plug.Conn{private: %{phoenix_swagger: %{valid: true}}} = conn, _opts), do: conn

  def call(conn, opts) do
    validation_failed_status = Keyword.get(opts, :validation_failed_status, 400)

    case ConnValidator.validate(conn) do
      {:ok, conn} ->
        conn |> put_private(:phoenix_swagger, %{valid: true})

      {:error, :no_matching_path} ->
        send_error_response(conn, 404, "API does not provide resource", conn.request_path)

      {:error, [{message, path} | _], _path} ->
        send_error_response(conn, validation_failed_status, message, path)

      {:error, message, path} ->
        send_error_response(conn, validation_failed_status, message, path)
    end
  end

  defp send_error_response(conn, status, message, path) do
    response = %{
      error: %{
        status: 400,
        code: "WRONG_DATA",
        message: message
      }
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Poison.encode!(response))
    |> halt()
  end
end
