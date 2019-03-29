defmodule MccTest.Support.Table.Account.Exp do
  @moduledoc """
  Table for expiration Account table.
  """

  use Mcc.Model.Table,
    table_opts: [
      type: :ordered_set,
      ram_copies: [node()],
      storage_properties: [
        ets: [:compressed, read_concurrency: true]
      ]
    ]

  defstruct [:key, :value]
end

defmodule MccTest.Support.Table.Account do
  @moduledoc """
  Account table.
  """

  alias MccTest.Support.Table.Account.Exp, as: AccountExp

  use Mcc.Rpc,
    target_list: [node()],
    retry_times: 3,
    rpc_timeout: 5000

  use Mcc.Model.Table,
    table_opts: [
      type: :set,
      ram_copies: [node()],
      storage_properties: [
        ets: [:compressed, read_concurrency: true]
      ]
    ],
    expiration_opts: [
      expiration_table: AccountExp,
      main_table: MccTest.Support.Table.Account,
      size_limit: 100,
      # 300M
      memory_limit: 300,
      waterline_ratio: 0.7,
      check_interval: 1_000
    ]

  defstruct([:id, :user_profile], true)

  rpc(get_with_ttl(k))
  rpc(get_with_ttl(k, ttl))

  def get_with_ttl(k, ttl \\ 10) do
    case get(k) do
      %{id: ^k, user_profile: _v} = old_object ->
        put(k, old_object, ttl)
        old_object

      _ ->
        :"$not_can_found"
    end
  end

  rpc(put_with_ttl(k, v))
  rpc(put_with_ttl(k, v, ttl))

  def put_with_ttl(k, v, ttl \\ 10) do
    async_put(k, %MccTest.Support.Table.Account{id: k, user_profile: v}, ttl)
  end

  #
end
