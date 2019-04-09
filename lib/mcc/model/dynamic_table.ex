defmodule Mcc.Model.DynamicTable do
  @moduledoc """
  Define a mnesia dynamic table.
  """

  require Logger

  defmacro __using__(opts) do
    quote do
      require Logger

      import Kernel, except: [defstruct: 1]
      import Mcc.Model.Builder

      alias Mcc.Async.Writer
      alias Mcc.Model.TableUtil

      @dynamic true
      @mnesia_opts unquote(Macro.escape(opts[:table_opts]))
      @expiration_opts unquote(Keyword.get(opts, :expiration_opts, []))
      @record_name __MODULE__
      @before_compile unquote(__MODULE__)

      @doc """
      Get expiration options for current table.
      """
      @spec get_expiration_opts(atom()) :: Keyword.t()
      def get_expiration_opts(table_name) do
        case Keyword.get(@expiration_opts, :expiration_module) do
          nil ->
            []

          _ ->
            {_, expiration_table} = get_expiration_tab(table_name)

            Keyword.merge(@expiration_opts,
              main_table: table_name,
              expiration_table: expiration_table
            )
        end
      end

      @doc """
      Get expiration table for main table.
      """
      @spec get_expiration_tab(atom()) :: nil | {atom(), atom()}
      def get_expiration_tab(table_name) do
        case Keyword.get(@expiration_opts, :expiration_module) do
          nil -> nil
          expiration_module -> {expiration_module, String.to_atom("#{table_name}_exp")}
        end
      end

      @doc """
      Return all keys from current table.
      """
      @spec keys(atom(), TableUtil.consistency_level()) :: [%__MODULE__{}]
      def keys(table_name, consistency_level \\ :async_dirty) do
        TableUtil.keys(table_name, consistency_level)
      end

      @doc """
      Return all records from current table by given `key`.
      """
      @spec get_all(atom(), term(), TableUtil.consistency_level()) :: [%__MODULE__{}]
      def get_all(table_name, key, consistency_level \\ :async_dirty) do
        table_name
        |> TableUtil.get_all(key, consistency_level)
        |> Enum.map(&record_to_struct/1)
      end

      @doc """
      Return first record from current table by given `key`.
      """
      @spec get(atom, term, TableUtil.consistency_level()) :: nil | map()
      def get(table_name, key, consistency_level \\ :async_dirty) do
        table_name
        |> get_all(key, consistency_level)
        |> List.first()
        |> case do
          nil ->
            nil

          %{__expire_time__: nil} = old_obj ->
            old_obj

          %{__expire_time__: expire_time} = old_obj ->
            if DateTime.to_unix(DateTime.utc_now()) >= expire_time do
              delete(table_name, key)
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
      @spec put(atom(), map(), TableUtil.consistency_level()) :: :ok
      def put(table_name, %{__struct__: __MODULE__} = struct, consistency_level \\ :async_dirty) do
        TableUtil.put(table_name, struct_to_record(struct), consistency_level)
      end

      @doc """
      Put with cache_time and ttl.
      """
      @spec put(atom(), term(), map(), integer(), TableUtil.consistency_level()) :: :ok
      def put(table_name, key, %{__struct__: __MODULE__} = struct, ttl, level \\ :async_dirty) do
        cache_time = DateTime.to_unix(DateTime.utc_now())
        set_ttl(table_name, struct, get_expiration_tab(table_name), key, cache_time, ttl, level)

        put(
          table_name,
          %{struct | __cache_time__: cache_time, __expire_time__: cache_time + ttl},
          level
        )
      end

      @doc """
      Put with cache_time and ttl through async writer.
      """
      @spec async_put(atom(), term(), map(), integer(), TableUtil.consistency_level()) :: :ok
      def async_put(table_name, key, struct, ttl, level \\ :async_dirty) do
        Writer.put(key, __MODULE__, :put, [table_name, key, struct, ttl, level])
      end

      @doc """
      Delete the record from current table by given `key`.
      """
      @spec delete(atom(), term(), TableUtil.consistency_level()) :: :ok
      def delete(table_name, key, consistency_level \\ :async_dirty) do
        table_name
        |> get_all(key, consistency_level)
        |> List.first()
        |> case do
          %{__expire_time__: old_expire_time} when not is_nil(old_expire_time) ->
            case get_expiration_tab(table_name) do
              nil ->
                nil

              {exp_mod, exp_tab} ->
                apply(exp_mod, :delete, [exp_tab, {old_expire_time, key}, consistency_level])
            end

          _ ->
            nil
        end

        TableUtil.mnesia_activity(
          fn -> :mnesia.delete(table_name, key, :write) end,
          consistency_level,
          table: table_name,
          operation: "delete",
          default: :ok
        )
      end

      @doc """
      First for current table.
      """
      @spec first(atom(), TableUtil.consistency_level()) :: term() | :"$end_of_table"
      def first(table_name, consistency_level \\ :async_dirty) do
        TableUtil.first(table_name, consistency_level)
      end

      @doc """
      Table info.
      """
      @spec table_info(atom(), atom()) :: term()
      def table_info(table_name, info_key) do
        TableUtil.table_info(table_name, info_key)
      end

      @doc """
      Set ttl.
      """
      @spec set_ttl(
              atom(),
              map(),
              {atom(), atom()} | nil,
              term(),
              integer(),
              integer(),
              TableUtil.consistency_level()
            ) :: :ok
      def set_ttl(_, _, nil, _, _, _, _), do: nil

      def set_ttl(
            table_name,
            %{__expire_time__: nil},
            {exp_mod, exp_tab},
            key,
            cache_time,
            ttl,
            consistency_level
          ) do
        table_name
        |> get_all(key, consistency_level)
        |> List.first()
        |> case do
          %{__expire_time__: old_expire_time} when not is_nil(old_expire_time) ->
            exp_mod.delete(exp_tab, {old_expire_time, key}, consistency_level)

          _ ->
            nil
        end

        exp_mod.put(
          exp_tab,
          %{__struct__: exp_mod, key: {cache_time + ttl, key}},
          consistency_level
        )
      end

      def set_ttl(
            _,
            %{__expire_time__: expire_time},
            {exp_mod, exp_tab},
            key,
            cache_time,
            ttl,
            level
          ) do
        exp_mod.delete(exp_tab, {expire_time, key}, level)
        exp_mod.put(exp_tab, %{__struct__: exp_mod, key: {cache_time + ttl, key}}, level)
      end

      defoverridable []
    end
  end

  defmacro __before_compile__(%Macro.Env{module: module}) do
    mnesia_opts = Module.get_attribute(module, :mnesia_opts)

    quote do
      alias Mcc.Expiration.Supervisor, as: ExpSup
      alias Mcc.Model

      @spec create_table(atom()) :: :ok | :error
      def create_table(table_name) do
        with :ok <- create_exp_table(table_name),
             :ok <- create_self_table(table_name),
             :ok <- create_expiration_process(table_name) do
          _ = Logger.info("[mcc] mnesia table #{table_name} created")
          :ok
        else
          err ->
            _ = Logger.error("[mcc] mnesia table #{table_name} create error: #{inspect(err)}")
            err
        end

        # create self
      end

      def table(table_name) do
        {
          {__MODULE__, table_name},
          [
            attributes: @fields,
            record_name: @record_name
          ]
          |> Keyword.merge(unquote(mnesia_opts))
        }
      end

      @doc false
      defp record_to_struct(record) do
        [@record_name | values] = record |> Tuple.to_list()
        fields = Enum.zip(@fields, values)
        struct(__MODULE__, fields)
      end

      @doc false
      defp struct_to_record(struct) do
        [
          @record_name
          | for field <- @fields do
              Map.get(struct, field)
            end
        ]
        |> List.to_tuple()
      end

      @doc false
      defp create_exp_table(table_name) do
        case get_expiration_tab(table_name) do
          nil -> :ok
          {exp_mod, exp_tab} -> apply(exp_mod, :create_table, [exp_tab])
        end
      end

      @doc false
      defp create_self_table(table_name) do
        {{_, tab_name}, tab_def} = table(table_name)

        case Model.create_table(tab_name, tab_def) do
          :ok -> :ok
          other -> {:error, other}
        end
      end

      @doc false
      defp create_expiration_process(table_name) do
        case get_expiration_opts(table_name) do
          [] -> :ok
          operation_opts -> ExpSup.add_expiration_worker(table_name, operation_opts)
        end
      end

      #
    end
  end

  # __end_of_module__
end
