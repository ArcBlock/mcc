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

  def put(key, value) do
    put(%__MODULE__{key: key, value: value})
  end
end

defmodule MccTest.Support.Table.Account do
  @moduledoc """
  Account table.
  """

  alias MccTest.Support.Table.Account.Exp, as: AccountExp

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

  def get_with_ttl(k, ttl \\ 10) do
    now = DateTime.to_unix(DateTime.utc_now())

    case get(k) do
      %{id: ^k, user_profile: _v} = old_object ->
        put(k, old_object, AccountExp, now, ttl)
        old_object

      _ ->
        nil
    end
  end

  def put_with_ttl(k, v, ttl \\ 10) do
    now = DateTime.to_unix(DateTime.utc_now())
    put(k, %MccTest.Support.Table.Account{id: k, user_profile: v}, AccountExp, now, ttl)
  end

  #
end
