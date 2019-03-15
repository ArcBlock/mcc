defmodule BuiltinMcc.Table.AWithExp.Exp do
  @moduledoc """
  Table for expiration.
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

defmodule BuiltinMcc.Table.AWithExp do
  @moduledoc """
  One table with expiration.
  The original data for this table only maint by current service.

  And there are no other service could operate the original data
  for this cache table.

  So, current service can continue the ttl when read data from table.
  """

  alias BuiltinMcc.Table.AWithExp.Exp, as: AWithExpExp

  use Mcc.Model.Table,
    table_opts: [
      type: :set,
      ram_copies: [node()],
      storage_properties: [
        ets: [:compressed, read_concurrency: true]
      ]
    ],
    expiration_opts: [
      expiration_table: AWithExpExp,
      main_table: __MODULE__,
      size_limit: 100,
      # 300M
      memory_limit: 300,
      waterline_ratio: 0.7,
      check_interval: 1_000
    ]

  defstruct([:key, :value], true)

  def check_cache_data(k) do
    get(k)
  end

  def get_with_ttl(k, ttl \\ 10) do
    case get(k) do
      %{key: ^k, value: _v} = old_object ->
        put(k, old_object, ttl)
        old_object

      _ ->
        :"$not_can_found"
    end
  end

  def put_with_ttl(k, v, ttl \\ 10) do
    put(k, %__MODULE__{key: k, value: v}, ttl)
  end

  def sync_dirty_put(k, v, ttl \\ 10) do
    put(k, %__MODULE__{key: k, value: v}, ttl, :sync_dirty)
  end

  # __end_of_module__
end
