defmodule BtrzExPlug.Plugs.ParseParamKeysTests do
  use ExUnit.Case, async: true
  alias BtrzExPlug.Plugs.ParseParamKeys

  setup_all do
    test_conn = %Plug.Conn{
      body_params: %{
        "firstName" => "Peter",
        "lastName" => "Davis"
      },
      query_params: %{
        "apiKey" => "anApiKey"
      },
      path_params: %{
        "programId" => "programId"
      }
    }

    {:ok, test_conn: test_conn}
  end

  describe "snake case params" do
    test "the keys on assigns.body_params should be snake_case", %{
      test_conn: conn
    } do
      %Plug.Conn{assigns: %{body_params: body_params}} = ParseParamKeys.call(conn, %{})

      assert %{"first_name" => "Peter", "last_name" => "Davis"} = body_params
    end

    test "the keys on assigns.query_params should be snake_case", %{
      test_conn: conn
    } do
      %Plug.Conn{assigns: %{query_params: query_params}} = ParseParamKeys.call(conn, %{})

      assert %{"api_key" => "anApiKey"} = query_params
    end

    test "the keys on assigns.path_params should be snake_case", %{
      test_conn: conn
    } do
      %Plug.Conn{assigns: %{path_params: path_params}} = ParseParamKeys.call(conn, %{})

      assert %{"program_id" => "programId"} = path_params
    end

    test "should use the function passed in the opts[:fun]", %{
      test_conn: conn
    } do
      %Plug.Conn{
        assigns: %{path_params: path_params, query_params: query_params, body_params: body_params}
      } = ParseParamKeys.call(conn, %{fun: &Recase.to_constant/1})

      assert %{"PROGRAM_ID" => "programId"} = path_params
      assert %{"FIRST_NAME" => "Peter", "LAST_NAME" => "Davis"} = body_params
      assert %{"API_KEY" => "anApiKey"} = query_params
    end
  end
end
