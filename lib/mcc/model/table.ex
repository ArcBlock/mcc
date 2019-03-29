defmodule Mcc.Model.Table do
  @moduledoc """
  Define a mnesia table.
  """

  require Logger

  defmacro __using__(opts) do
    quote do
      require Logger

      import Kernel, except: [defstruct: 1]
      import Mcc.Model.Builder

      alias Mcc.Model.Table
      alias Mcc.Async.Writer

      @mnesia_opts unquote(Macro.escape(opts[:table_opts]))
      @expiration_opts unquote(Keyword.get(opts, :expiration_opts, []))
      @table_name __MODULE__
      @record_name __MODULE__
      @before_compile unquote(__MODULE__)

      @type consistency_level ::
              :transaction
              | {:transaction, integer()}
              | :sync_transaction
              | {:sync_transaction, integer()}
              | :async_dirty
              | :sync_dirty

      @doc """
      Get expiration options for current table.
      """
      @spec get_expiration_opts :: Keyword.t()
      def get_expiration_opts, do: @expiration_opts

      @doc """
      Get expiration table for main table.
      """
      @spec get_expiration_tab :: nil | atom()
      def get_expiration_tab do
        Keyword.get(@expiration_opts, :expiration_table)
      end

      @doc """
      Return all keys from current table.
      """
      @spec keys(consistency_level) :: [%__MODULE__{}]
      def keys(consistency_level \\ :async_dirty) do
        Table.mnesia_activity(fn -> :mnesia.all_keys(@table_name) end, consistency_level,
          table: @table_name,
          operation: "get all keys",
          default: []
        )
      end

      @doc """
      Return all records from current table by given `key`.
      """
      @spec get_all(term(), consistency_level) :: [%__MODULE__{}]
      def get_all(key, consistency_level \\ :async_dirty) do
        fn -> :mnesia.read(@table_name, key) end
        |> Table.mnesia_activity(consistency_level,
          table: @table_name,
          operation: "get all records",
          default: []
        )
        |> Enum.map(&record_to_struct/1)
      end

      @doc """
      Return first record from current table by given `key`.
      """
      @spec get(term(), consistency_level) :: nil | map()
      def get(key, consistency_level \\ :async_dirty) do
        key
        |> get_all(consistency_level)
        |> List.first()
        |> case do
          nil ->
            nil

          %{__expire_time__: nil} = old_obj ->
            old_obj

          %{__expire_time__: expire_time} = old_obj ->
            if DateTime.to_unix(DateTime.utc_now()) >= expire_time do
              delete(key)
              nil
            else
              old_obj
            end

          old_obj ->
            old_obj
        end
      end

      @doc """
      Put into current table.
      """
      @spec put(map(), consistency_level) :: :ok
      def put(%{__struct__: __MODULE__} = struct, consistency_level \\ :async_dirty) do
        Table.mnesia_activity(
          fn -> :mnesia.write(@table_name, struct_to_record(struct), :write) end,
          consistency_level,
          table: @table_name,
          operation: "write",
          default: :ok
        )
      end

      @doc """
      Put with cache_time and ttl.
      """
      @spec put(term(), map(), integer(), consistency_level) :: :ok
      def put(key, %{__struct__: __MODULE__} = struct, ttl, level \\ :async_dirty) do
        cache_time = DateTime.to_unix(DateTime.utc_now())
        set_ttl(struct, get_expiration_tab(), key, cache_time, ttl, level)
        put(%{struct | __cache_time__: cache_time, __expire_time__: cache_time + ttl}, level)
      end

      @doc """
      Put with cache_time and ttl through async writer.
      """
      @spec async_put(term(), map(), integer(), consistency_level) :: :ok
      def async_put(key, struct, ttl, level \\ :async_dirty) do
        Writer.put(key, __MODULE__, :put, [key, struct, ttl, level])
      end

      @doc """
      Delete the record from current table by given `key`.
      """
      @spec delete(term(), consistency_level) :: :ok
      def delete(key, consistency_level \\ :async_dirty) do
        key
        |> get_all(consistency_level)
        |> List.first()
        |> case do
          %{__expire_time__: old_expire_time} when not is_nil(old_expire_time) ->
            case get_expiration_tab() do
              nil -> nil
              exp_tab -> apply(exp_tab, :delete, [{old_expire_time, key}, consistency_level])
            end

          _ ->
            nil
        end

        Table.mnesia_activity(
          fn -> :mnesia.delete(@table_name, key, :write) end,
          consistency_level,
          table: @table_name,
          operation: "delete",
          default: :ok
        )
      end

      @doc """
      First for current table.
      """
      @spec first(consistency_level) :: term() | :"$end_of_table"
      def first(consistency_level \\ :async_dirty) do
        Table.mnesia_activity(
          fn -> :mnesia.first(@table_name) end,
          consistency_level,
          table: @table_name,
          operation: "first",
          default: :"$end_of_table"
        )
      end

      @doc """
      Table info.
      """
      @spec table_info(atom()) :: term()
      def table_info(infokey) do
        :mnesia.table_info(@table_name, infokey)
      catch
        :exit, reason ->
          Logger.warn("Get table info for #{__MODULE__} error, #{inspect(reason)}")
          nil
      end

      @doc """
      Set ttl.
      """
      @spec set_ttl(map(), atom() | nil, term(), integer(), integer(), consistency_level) :: :ok
      def set_ttl(_, nil, _, _, _, _), do: nil

      def set_ttl(%{__expire_time__: nil}, exp_tab, key, cache_time, ttl, consistency_level) do
        key
        |> get_all(consistency_level)
        |> List.first()
        |> case do
          %{__expire_time__: old_expire_time} when not is_nil(old_expire_time) ->
            exp_tab.delete({old_expire_time, key}, consistency_level)

          _ ->
            nil
        end

        exp_tab.put(%{__struct__: exp_tab, key: {cache_time + ttl, key}}, consistency_level)
      end

      def set_ttl(%{__expire_time__: expire_time}, exp_tab, key, cache_time, ttl, level) do
        exp_tab.delete({expire_time, key}, level)
        exp_tab.put(%{__struct__: exp_tab, key: {cache_time + ttl, key}}, level)
      end

      defoverridable []
    end
  end

  defmacro __before_compile__(%Macro.Env{module: module}) do
    mnesia_opts = Module.get_attribute(module, :mnesia_opts)

    quote do
      def table do
        {
          @table_name,
          [
            attributes: @fields,
            record_name: @record_name
          ]
          |> Keyword.merge(unquote(mnesia_opts))
        }
      end

      defp record_to_struct(record) do
        [@record_name | values] = record |> Tuple.to_list()
        fields = Enum.zip(@fields, values)
        struct(__MODULE__, fields)
      end

      defp struct_to_record(struct) do
        [
          @record_name
          | for field <- @fields do
              Map.get(struct, field)
            end
        ]
        |> List.to_tuple()
      end
    end
  end

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
