defmodule Mcc.Lib do
  @moduledoc """
  This module contains functions to manipulate cluster based on mnesia.

  Includes:

  1, start mnesia and mnesia table
  2, make node join into the mnesia cluster
  3, make node leave from the mnesia cluster
  4, remove one node from mnesia cluster
  5, get status of mnesia cluster
  """

  @doc """
  Tries to start mnesia and create or copy mnesia table.
  It will raises an exception in case of failure, return `:ok` if successful,
  or `{:error, reason}` if an error occurs.

  """
  @spec start :: :ok | {:error, term()}
  def start do
    :ok = ensure_ok(ensure_data_dir())
    :ok = ensure_ok(init_mnesia_schema())
    :ok = :mnesia.start()
    :ok = init_tables()
    :ok = wait_for(:tables)
  end

  @doc """
  Make one node join into the mnesia cluster.
  """
  @spec join_cluster(node()) :: :ok | {:error, term()}
  def join_cluster(node_name) do
    :ok = ensure_ok(ensure_stopped())
    :ok = ensure_ok(delete_schema())
    :ok = ensure_ok(ensure_started())
    :ok = ensure_ok(connect(node_name))
    :ok = ensure_ok(copy_schema(node()))
    :ok = copy_tables()
    :ok = ensure_ok(wait_for(:tables))
  end

  @doc """
  Make one node leave from the mnesia cluster.
  """
  @spec leave_cluster ::
          :ok
          | {:error, :node_not_in_cluster}
          | {:error, {:failed_to_leave, node()}}
  def leave_cluster do
    leave_cluster(running_nodes() -- [node()])
  end

  @doc """
  Remove one node from the mnesia cluster.
  """
  @spec remove_from_cluster(node()) ::
          :ok
          | {:error, :node_not_in_cluster}
          | {:error, term()}
  def remove_from_cluster(node_name) when node_name != node() do
    case {node_in_cluster?(node_name), running_db_node?(node_name)} do
      {true, true} ->
        :ok = ensure_ok(:rpc.call(node_name, __MODULE__, :ensure_stopped, []))
        :ok = ensure_ok(del_schema_copy(node_name))
        :ok = ensure_ok(:rpc.call(node_name, __MODULE__, :delete_schema, []))

      {true, false} ->
        :ok = ensure_ok(del_schema_copy(node_name))
        :ok = ensure_ok(:rpc.call(node_name, __MODULE__, :delete_schema, []))

      {false, _} ->
        {:error, :node_not_in_cluster}
    end
  end

  @doc """
  Get status of the mnesia cluster.
  """
  @spec status :: list()
  def status do
    running = :mnesia.system_info(:running_db_nodes)
    stopped = :mnesia.system_info(:db_nodes) -- running
    [{:running_nodes, running}, {:stopped_nodes, stopped}]
  end

  @doc """
  Delete schema copy of given node.
  """
  @spec del_schema_copy(node()) :: :ok | {:error, any()}
  def del_schema_copy(node_name) do
    case :mnesia.del_table_copy(:schema, node_name) do
      {:atomic, :ok} -> :ok
      {:aborted, reason} -> {:error, reason}
    end
  end

  @doc """
  Delete schema information in local node.
  """
  @spec delete_schema :: :ok | {:error, any()}
  def delete_schema, do: :mnesia.delete_schema([node()])

  @doc """
  Ensure mnesia stoppted.
  """
  @spec ensure_stopped :: :ok | {:error, any()}
  def ensure_stopped do
    _ = :mnesia.stop()
    wait_for(:stop)
  end

  @doc """
  Get all nodes in current mnesia cluster.
  """
  @spec all_nodes :: [node()]
  def all_nodes, do: :mnesia.system_info(:db_nodes)

  @doc """
  Get all running nodes in current mnesia cluster.
  """
  @spec running_nodes :: [node()]
  def running_nodes, do: :mnesia.system_info(:running_db_nodes)

  @doc """
  Get all not running nodes in current mnesia cluster.
  """
  @spec not_running_nodes :: [node()]
  def not_running_nodes, do: all_nodes() -- running_nodes()

  @doc """
  Copy mnesia table from remote node.
  """
  @spec copy_table(atom(), atom()) :: :ok | {:error, any()}
  def copy_table(name, ram_or_disc \\ :ram_copies) do
    ensure_tab(:mnesia.add_table_copy(name, node(), ram_or_disc))
  end

  @doc """
  Create mnesia table.
  """
  @spec create_table(atom(), list()) :: :ok | {:error, any()}
  def create_table(name, tabdef) do
    ensure_tab(:mnesia.create_table(name, tabdef))
  end

  @doc false
  defp ensure_data_dir do
    mnesia_dir = :mnesia.system_info(:directory)

    case :filelib.ensure_dir(:filename.join(mnesia_dir, :foo)) do
      :ok -> :ok
      {:error, reason} -> {:error, {:mnesia_dir_error, mnesia_dir, reason}}
    end
  end

  @doc false
  defp init_mnesia_schema do
    case :mnesia.system_info(:extra_db_nodes) do
      [] -> :mnesia.create_schema([node()])
      [_ | _] -> :ok
    end
  end

  @doc false
  defp copy_schema(node_name) do
    case :mnesia.change_table_copy_type(:schema, node_name, :disc_copies) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, :schema, _node_name, :disc_copies}} -> :ok
      {:aborted, error} -> {:error, error}
    end
  end

  @doc false
  defp init_tables do
    case :mnesia.system_info(:extra_db_nodes) do
      [] -> create_tables()
      [_ | _] -> copy_tables()
    end
  end

  @doc false
  defp create_tables do
    :mcc
    |> Application.get_env(:mnesia_table_modules, [])
    |> Enum.each(fn t -> Code.ensure_loaded?(t) and apply(t, :boot_tables, []) end)
  end

  @doc false
  defp copy_tables do
    :mcc
    |> Application.get_env(:mnesia_table_modules, [])
    |> Enum.each(fn t -> Code.ensure_loaded?(t) and apply(t, :copy_tables, []) end)
  end

  @doc false
  defp ensure_started do
    _ = :mnesia.start()
    wait_for(:start)
  end

  @doc false
  defp connect(node_name) do
    case :mnesia.change_config(:extra_db_nodes, [node_name]) do
      {:ok, [_node_name]} -> :ok
      {:ok, []} -> {:error, {:failed_to_connect, node_name}}
      error -> error
    end
  end

  @doc false
  defp leave_cluster([]), do: {:error, :node_not_in_cluster}

  defp leave_cluster(nodes) when is_list(nodes) do
    case Enum.any?(nodes, fn node_name -> leave_cluster(node_name) end) do
      true -> :ok
      _ -> {:error, {:failed_to_leave, nodes}}
    end
  end

  defp leave_cluster(node_name) when is_atom(node_name) and node_name != node() do
    case running_db_node?(node_name) do
      true ->
        :ok = ensure_ok(ensure_stopped())
        :ok = ensure_ok(:rpc.call(node_name, __MODULE__, :del_schema_copy, [node()]))
        :ok = ensure_ok(delete_schema())

      false ->
        {:error, {:node_name_not_running, node_name}}
    end
  end

  @doc false
  defp node_in_cluster?(node_name), do: Enum.member?(all_nodes(), node_name)

  @doc false
  defp running_db_node?(node_name), do: Enum.member?(running_nodes(), node_name)

  @doc false
  defp wait_for(:start) do
    case :mnesia.system_info(:is_running) do
      :yes ->
        :ok

      :starting ->
        Process.sleep(1_000)
        wait_for(:start)

      _ ->
        {:error, :mnesia_unexpectedly_stopped}
    end
  end

  defp wait_for(:stop) do
    case :mnesia.system_info(:is_running) do
      :no ->
        :ok

      :stopping ->
        Process.sleep(1_000)
        wait_for(:stop)

      _ ->
        {:error, :mnesia_unexpectedly_running}
    end
  end

  defp wait_for(:tables) do
    :local_tables
    |> :mnesia.system_info()
    |> :mnesia.wait_for_tables(Application.get_env(:mcc, :mnesia_table_wait_timeout, 150_000))
    |> case do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
      {:timeout, badtables} -> {:error, {:timetout, badtables}}
    end
  end

  @doc false
  defp ensure_ok(:ok), do: :ok
  defp ensure_ok({:error, {_, {:already_exists, _}}}), do: :ok
  defp ensure_ok(any), do: {:error, any}

  @doc false
  defp ensure_tab({:atomic, :ok}), do: :ok
  defp ensure_tab({:aborted, {:already_exists, _}}), do: :ok
  defp ensure_tab({:aborted, {:already_exists, _name, _node_name}}), do: :ok
  defp ensure_tab({:aborted, error}), do: {:error, error}

  # __end_of_module__
end
