defmodule MccStore do
  @moduledoc """
  Documentation for MccStore.
  """

  use Mcc.Model

  import_table(MccStore.Table.AWithExp)
  import_table(MccStore.Table.AWithExp.Exp)

  # __end_of_module__
end
