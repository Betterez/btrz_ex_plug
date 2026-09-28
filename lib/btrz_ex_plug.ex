defmodule BtrzExPlug do
  @moduledoc """
  BtrzExPlug is the package that contains all plugs that are used across Betterez

  Plugs:
    * `BtrzExPlug.Plugs.ParseParamKeys`: Parse params based on a function
    * `BtrzExPlug.Plugs.HttpLogger`: HTTP req/res activity logger
    * `BtrzExPlug.Plugs.SwaggerValidate`: Validate requests against swagger

  Logging helpers:
    * `BtrzExPlug.ApplicationLogFormatter`: Application file log formatter
  """
end
