defmodule MccTest.Support.Table.DynamicAccount.Exp do
  @moduledoc """
  Table for expiration Account table.
  """

  use Mcc.Model.DynamicTable,
    table_opts: [
      type: :ordered_set,
      ram_copies: [node()],
      storage_properties: [
        ets: [:compressed, read_concurrency: true]
      ]
    ]

  defstruct [:key, :value]
end

defmodule MccTest.Support.Table.DynamicAccount do
  @moduledoc """
  Account table.
  """

  alias MccTest.Support.Table.DynamicAccount.Exp, as: DynamicAccountExp

  # use Mcc.Rpc,
  #   target_list: [node()],
  #   retry_times: 3,
  #   rpc_timeout: 5000

  use Mcc.Model.DynamicTable,
    table_opts: [
      type: :set,
      ram_copies: [node()],
      storage_properties: [
        ets: [:compressed, read_concurrency: true]
      ]
    ],
    expiration_opts: [
      expiration_module: DynamicAccountExp,
      main_module: __MODULE__,
      size_limit: 100,
      # 300M
      memory_limit: 300,
      waterline_ratio: 0.7,
      check_interval: 1_000
    ]

  defstruct([:id, :user_profile], true)

  def get_with_ttl(table_name, k, ttl \\ 10) do
    case get(table_name, k) do
      %{id: ^k, user_profile: _v} = old_object ->
        put(table_name, k, old_object, ttl)
        old_object

      _ ->
        :"$not_can_found"
    end
  end

  def put_with_ttl(table_name, k, v, ttl \\ 10) do
    put(table_name, k, %MccTest.Support.Table.DynamicAccount{id: k, user_profile: v}, ttl)
  end

  #
end
