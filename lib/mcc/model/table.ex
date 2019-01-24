defmodule Mcc.Model.Table do
  @moduledoc """
  Define a mnesia table.
  """

  defmacro __using__(opts) do
    quote do
      require Logger

      import Kernel, except: [defstruct: 1]
      import Mcc.Model.Builder

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
      Return all keys from current table.
      """
      def keys do
        :mnesia.dirty_all_keys(@table_name)
      catch
        :exit, reason ->
          Logger.warn("Get keys from #{__MODULE__} error, #{inspect(reason)}")
          []
      end

      @doc """
      Return all records from current table by given `key`.
      """
      @spec get_all(term()) :: [map()]
      def get_all(key) do
        @table_name
        |> :mnesia.dirty_read(key)
        |> Enum.map(&record_to_struct/1)
      catch
        :exit, reason ->
          Logger.warn("Get all records from #{__MODULE__} by key error, #{inspect(reason)}")
          []
      end

      @doc """
      Return first record from current table by given `key`.
      """
      @spec get(term()) :: nil | map()
      def get(key) do
        key
        |> get_all()
        |> List.first()
        |> case do
          nil ->
            nil

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
      @spec put(map()) :: :ok
      def put(%{__struct__: __MODULE__} = struct) do
        :mnesia.dirty_write(@table_name, struct_to_record(struct))
      catch
        :exit, reason ->
          Logger.warn("Write #{__MODULE__} error, #{inspect(reason)}")
          :ok
      end

      @doc """
      Put with cache_time and ttl.
      """
      @spec put(term(), map(), atom(), non_neg_integer(), non_neg_integer()) :: :ok
      def put(key, %{__struct__: __MODULE__} = struct, exp_tab, cache_time, ttl) do
        set_ttl(struct, exp_tab, key, cache_time, ttl)
        put(%{struct | __cache_time__: cache_time, __expire_time__: cache_time + ttl})
      end

      @doc """
      Delete the record from current table by given `key`.
      """
      @spec delete(term()) :: :ok
      def delete(key) do
        :mnesia.dirty_delete(@table_name, key)
      catch
        :exit, reason ->
          Logger.warn("Delete from #{__MODULE__} error, #{inspect(reason)}")
          :ok
      end

      @doc """
      Delete the record from current table by given `object`.
      """
      @spec delete_object(map()) :: :ok
      def delete_object(object) do
        :mnesia.dirty_delete_object(object)
      catch
        :exit, reason ->
          Logger.warn("Delete object from #{__MODULE__} error, #{inspect(reason)}")
          :ok
      end

      @doc """
      First for current table.
      """
      @spec first :: term() | :"$end_of_table"
      def first do
        :mnesia.dirty_first(@table_name)
      catch
        :exit, reason ->
          Logger.warn("First from #{__MODULE__} error, #{inspect(reason)}")
          :"$end_of_table"
      end

      @doc """
      Last for current table.
      """
      @spec last :: term() | :"$end_of_table"
      def last do
        :mnesia.dirty_last(@table_name)
      catch
        :exit, reason ->
          Logger.warn("Last from #{__MODULE__} error, #{inspect(reason)}")
          :"$end_of_table"
      end

      @doc """
      Next key for current table.
      """
      @spec next(term()) :: term() | :"$end_of_table"
      def next(key) do
        :mnesia.dirty_next(@table_name, key)
      catch
        :exit, reason ->
          Logger.warn("Next from #{__MODULE__} error, #{inspect(reason)}")
          :"$end_of_table"
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
      @spec set_ttl(map(), atom(), term(), non_neg_integer(), non_neg_integer()) :: :ok
      def set_ttl(%{__expire_time__: expire_time}, exp_tab, key, cache_time, ttl) do
        exp_tab.delete({expire_time, key})
        exp_tab.put({cache_time + ttl, key}, 0)
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
