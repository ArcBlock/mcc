# Mcc (Mnesia Cluster Cache)

`mcc` is Mnesia Cluster Cache, which support expiration and cluster.

## usage

There are some steps to use mcc:

  - define table
  - define model
  - start expiration process

### define table

Mcc support expiration and each table need one assistant table to store expiration information.

```elixir
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
      memory_limit: 300
    ]

  defstruct([:id, :user_profile], true)
```

Like above table definition, the `table_opts` is from [mnesia create table](http://erlang.org/doc/man/mnesia.html#create_table-2). And `expiration_opts` has several option:

- expiration_table
  which table to store expiration information

- main_table
  current table

- size_limit
  the table size limit

- memory_limit
  the memory usage limit, unit is `mega byte`

After define the table, need define the fields for the table, user can use `defstruct/1,2` to define the table's fields. Multi-fields use `[]` to organize, and fields should use `atom`. The second parameter for `defstruct` is represent if use cache expiration mechanism.

For the assistant table, the definition will be like:

```elixir
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
```

## define model

After define table, user need to define model, it's not difficult:

```elixir
defmodule MccTest.Support.Cache do
  @moduledoc """
  Definition for cache test.
  """

  use Mcc.Model

  import_table(MccTest.Support.Table.Account.Exp)
  import_table(MccTest.Support.Table.Account)
end
```

define model is import the tables which defined before.

## start expiration process

`mcc` use one long-lived process to scan the mnesia table for expiration. User(application) need to start the process explicitly:

```elixir
MccTest.Support.Cache.start_expiration_process()
```

Generally speaking, it will be put into application start.

[One complete example could be found in the test cases]
