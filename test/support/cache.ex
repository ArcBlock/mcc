defmodule MccTest.Support.Cache do
  @moduledoc """
  Definition for cache test.
  """

  use Mcc.Model

  import_table(MccTest.Support.Table.Account.Exp)
  import_table(MccTest.Support.Table.Account)
  import_table(MccTest.Support.Table.DynamicAccount.Exp, table_name: :import_a_1_exp)
  import_table(MccTest.Support.Table.DynamicAccount, table_name: :import_a_1)
  import_table(MccTest.Support.Table.DynamicAccount.Exp, table_name: :import_a_2_exp)
  import_table(MccTest.Support.Table.DynamicAccount, table_name: :import_a_2)
  import_table(MccTest.Support.Table.DynamicAccount.Exp, table_name: :import_a_3_exp)
  import_table(MccTest.Support.Table.DynamicAccount, table_name: :import_a_3)
  import_table(MccTest.Support.Table.DynamicAccount.Exp, table_name: :import_a_4_exp)
  import_table(MccTest.Support.Table.DynamicAccount, table_name: :import_a_4)
  #
end
