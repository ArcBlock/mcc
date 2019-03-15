defmodule BuiltinMcc.Cache do
  @moduledoc """
  BuiltinMcc cache.
  """

  use Mcc.Model

  import_table(BuiltinMcc.Table.AWithExp.Exp)
  import_table(BuiltinMcc.Table.AWithExp)
end
