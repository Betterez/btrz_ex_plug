defmodule BtrzExPlug.Plugs.ParseParamKeys do
  @moduledoc """
  This plugs adds the following fields to the assigns field of %Plug.Conn{}.
    * `body_params`: the result of apply a function to body_params attribute of the conn
    * `path_params`: the result of apply a function to path_params attribute of the conn
    * `query_params`: the result of apply a function to query_params attribute of the conn

  In order to use add the following line in your router:
    ```elixir
    plug(BtrzExPlug.Plugs.ParseParamKeys)
    ```
  """
  import Plug.Conn

  @to_snake &Recase.to_snake/1

  defp rename_keys(map, fun) do
    Enum.reduce(map, %{}, fn {key, val}, acc -> Map.put(acc, fun.(key), val) end)
  end

  @doc """
  """
  @spec init(Keyword.t()) :: Keyword.t()
  def init(opts), do: opts

  @doc """
  Generates a Plug.Conn that have body_params, path_params and query_params added to the assigns attribute.

  Options:
    * `:fun` - (map) -> (map): The function that will be applied to each params. The default uses `Recase.to_snake/1`

  ## Examples

      iex> BtrzExPlug.Plugs.ParseParamKeys.call(%Plug.Conn{
      ...>  body_params: %{"firstName" => "Peter"},
      ...>  query_params: %{"apiKey" => "anApiKey"},
      ...>  path_params: %{"programId" => "programId"}
      ...> }, [])
      %Plug.Conn{
        assigns: %{
          body_params: %{"first_name" => "Peter"},
          query_params: %{"api_key" => "anApiKey"},
          path_params: %{"program_id" => "programId"}
        }
      }

  """
  @spec call(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  def call(
        %Plug.Conn{body_params: body_params, path_params: path_params, query_params: query_params} =
          conn,
        opts
      ) do
    fun = opts[:fun] || @to_snake

    conn
    |> assign(:body_params, rename_keys(body_params, fun))
    |> assign(:path_params, rename_keys(path_params, fun))
    |> assign(:query_params, rename_keys(query_params, fun))
  end
end
