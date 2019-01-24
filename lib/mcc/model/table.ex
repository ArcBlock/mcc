defmodule Mcc.Model.Table do
  @moduledoc """
  Define a mnesia table.
  """

  defmacro __using__(opts) do
    quote do
      import Kernel, except: [defstruct: 1]
      import Mcc.Model.Builder

      @mnesia_opts unquote(Macro.escape(opts[:table_opts]))
      @expiration_opts unquote(Keyword.get(opts, :expiration_opts, []))
      @table_name __MODULE__
      @record_name __MODULE__
      @before_compile unquote(__MODULE__)

      def get_expiration_opts do
        @expiration_opts
      end

      def keys do
        @table_name
        |> :mnesia.dirty_all_keys()
      end

      def last do
        @table_name
        |> :mnesia.dirty_last()
      end

      def first do
        @table_name
        |> :mnesia.dirty_first()
      end

      def get_all(key) do
        @table_name
        |> :mnesia.dirty_read(key)
        |> Enum.map(&record_to_struct/1)
      end

      @doc """
      Return first record from current table by given `key`.
      """
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
      def put(%{__struct__: __MODULE__} = struct) do
        :mnesia.dirty_write(@table_name, struct_to_record(struct))
      end

      @doc """
      Put with cache_time and ttl.
      """
      def put(key, %{__struct__: __MODULE__} = struct, exp_tab, cache_time, ttl) do
        set_ttl(struct, exp_tab, key, cache_time, ttl)
        put(%{struct | __cache_time__: cache_time, __expire_time__: cache_time + ttl})
      end

      def delete(key) do
        @table_name
        |> :mnesia.dirty_delete(key)
      end

      def delete_object(object) do
        object
        |> :mnesia.dirty_delete_object()
      end

      @spec delete_all_objects() :: :ok
      def delete_all_objects do
        keys()
        |> Enum.each(fn key -> delete(key) end)
      end

      @spec all_objects() :: list()
      def all_objects do
        keys()
        |> Enum.map(fn key -> get(key) end)
      end

      @doc """
      Next key for current table.
      """
      def next(key), do: :mnesia.dirty_next(@table_name, key)

      @doc """
      Table info.
      """
      def table_info(infokey), do: :mnesia.table_info(@table_name, infokey)

      @doc """
      Set ttl.
      """
      def set_ttl(%{__expire_time__: expire_time}, exp_tab, key, cache_time, ttl) do
        exp_tab.delete({expire_time, key})
        exp_tab.put({cache_time + ttl, key}, 0)
      end

      defoverridable keys: 0,
                     get_all: 1,
                     get: 1,
                     put: 1,
                     delete: 1
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
