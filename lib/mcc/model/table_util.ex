defmodule Mcc.Model.TableUtil do
  @moduledoc """
  Table util module.
  """

  require Logger

  @type consistency_level ::
          :transaction
          | {:transaction, integer()}
          | :sync_transaction
          | {:sync_transaction, integer()}
          | :async_dirty
          | :sync_dirty

  @doc """
  Return all keys from current table.
  """
  @spec keys(atom, consistency_level) :: [map]
  def keys(table_name, consistency_level) do
    mnesia_activity(fn -> :mnesia.all_keys(table_name) end, consistency_level,
      table: table_name,
      operation: "get all keys",
      default: []
    )
  end

  @doc """
  Return all records from current table by given `key`.
  """
  @spec get_all(atom, term, consistency_level) :: [map]
  def get_all(table_name, key, consistency_level) do
    fn -> :mnesia.read(table_name, key) end
    |> mnesia_activity(consistency_level,
      table: table_name,
      operation: "get all records",
      default: []
    )
  end

  @doc """
  Put into current table.
  """
  @spec put(atom, tuple, consistency_level) :: :ok
  def put(table_name, tuple, consistency_level) do
    mnesia_activity(
      fn -> :mnesia.write(table_name, tuple, :write) end,
      consistency_level,
      table: table_name,
      operation: "write",
      default: :ok
    )
  end

  @doc """
  First for current table.
  """
  @spec first(atom, consistency_level) :: term() | :"$end_of_table"
  def first(table_name, consistency_level \\ :async_dirty) do
    mnesia_activity(
      fn -> :mnesia.first(table_name) end,
      consistency_level,
      table: table_name,
      operation: "first",
      default: :"$end_of_table"
    )
  end

  @doc """
  Table info.
  """
  @spec table_info(atom, atom) :: term()
  def table_info(table_name, info_key) do
    :mnesia.table_info(table_name, info_key)
  catch
    :exit, reason ->
      Logger.warn("Get table info for #{table_name} error, #{inspect(reason)}")
      nil
  end

  @doc false
  def mnesia_activity(fun, access_context, operation_opts) do
    :mnesia.activity(access_context, fun)
  catch
    :exit, reason ->
      table = Keyword.get(operation_opts, :table)
      operation = Keyword.get(operation_opts, :operation)
      default = Keyword.get(operation_opts, :default)
      _ = Logger.warn("[mcc] table activity warn, #{operation} from #{table}, #{inspect(reason)}")
      default
  end

  # __end_of_module__
end
