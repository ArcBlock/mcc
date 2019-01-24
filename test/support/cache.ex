defmodule MccTest.Support.Cache do
  @moduledoc """
  Definition for cache test.
  """

  use Mcc.Model

  import_table(MccTest.Support.Table.Account.Exp)
  import_table(MccTest.Support.Table.Account)
  #
end
