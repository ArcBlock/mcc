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

      alias Mcc.Async.Writer
      alias Mcc.Model.TableUtil

      @mnesia_opts unquote(Macro.escape(opts[:table_opts]))
      @expiration_opts unquote(Keyword.get(opts, :expiration_opts, []))
      @table_name __MODULE__
      @record_name __MODULE__
      @before_compile unquote(__MODULE__)

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
      @spec keys(TableUtil.consistency_level()) :: [%__MODULE__{}]
      def keys(consistency_level \\ :async_dirty) do
        TableUtil.keys(@table_name, consistency_level)
      end

      @doc """
      Return all records from current table by given `key`.
      """
      @spec get_all(term(), TableUtil.consistency_level()) :: [%__MODULE__{}]
      def get_all(key, consistency_level \\ :async_dirty) do
        @table_name
        |> TableUtil.get_all(key, consistency_level)
        |> Enum.map(&record_to_struct/1)
      end

      @doc """
      Return first record from current table by given `key`.
      """
      @spec get(term(), TableUtil.consistency_level()) :: nil | map()
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
      @spec put(map(), TableUtil.consistency_level()) :: :ok
      def put(%{__struct__: __MODULE__} = struct, consistency_level \\ :async_dirty) do
        TableUtil.put(@table_name, struct_to_record(struct), consistency_level)
      end

      @doc """
      Put with cache_time and ttl.
      """
      @spec put(term(), map(), integer(), TableUtil.consistency_level()) :: :ok
      def put(key, %{__struct__: __MODULE__} = struct, ttl, level \\ :async_dirty) do
        cache_time = DateTime.to_unix(DateTime.utc_now())
        set_ttl(struct, get_expiration_tab(), key, cache_time, ttl, level)
        put(%{struct | __cache_time__: cache_time, __expire_time__: cache_time + ttl}, level)
      end

      @doc """
      Put with cache_time and ttl through async writer.
      """
      @spec async_put(term(), map(), integer(), TableUtil.consistency_level()) :: :ok
      def async_put(key, struct, ttl, level \\ :async_dirty) do
        Writer.put(key, __MODULE__, :put, [key, struct, ttl, level])
      end

      @doc """
      Delete the record from current table by given `key`.
      """
      @spec delete(term(), TableUtil.consistency_level()) :: :ok
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

        TableUtil.mnesia_activity(
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
      @spec first(TableUtil.consistency_level()) :: term() | :"$end_of_table"
      def first(consistency_level \\ :async_dirty) do
        TableUtil.first(@table_name, consistency_level)
      end

      @doc """
      Table info.
      """
      @spec table_info(atom()) :: term()
      def table_info(info_key) do
        TableUtil.table_info(@table_name, info_key)
      end

      @doc """
      Set ttl.
      """
      @spec set_ttl(
              map(),
              atom() | nil,
              term(),
              integer(),
              integer(),
              TableUtil.consistency_level()
            ) :: :ok
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

  # __end_of_module__
end
