defmodule Mcc do
  @moduledoc """
  Documentation for Mcc.
  """

  alias Mcc.{Cache, Lib}

  defdelegate start, to: Lib

  @doc """

  """
  def register_guard do
    Process.register(self(), __MODULE__)
  end

  @doc """
  Make one node join into the cluster.
  """
  @spec join(atom()) ::
          :ok
          | {:error, {:can_not_join_self, atom()}}
          | {:error, {:node_not_running, atom()}}
          | {:error, {:already_clustered, atom()}}
          | {:error, term()}
  def join(node_name) when node_name == node() do
    {:error, {:can_not_join_self, node_name}}
  end

  def join(node_name) when is_atom(node_name) do
    case {is_running?(node_name), is_clustered?(node_name)} do
      {true, false} -> Lib.join_cluster(node_name)
      {false, false} -> {:error, {:node_not_running, node_name}}
      {_, true} -> {:error, {:already_clustered, node_name}}
    end
  end

  @doc """
  Make one node leave from the cluster.
  """
  @spec leave ::
          :ok
          | {:error, :node_not_in_cluster}
          | {:error, {:failed_to_leave, node()}}
          | {:error, :node_not_in_cluster}
  def leave do
    case is_clustered?(node()) do
      true -> Lib.leave_cluster()
      _ -> {:error, :node_not_in_cluster}
    end
  end

  @doc """
  Remove one node from the cluster.
  """
  @spec remove(atom()) ::
          :ok
          | {:error, :can_not_remove_self}
          | {:error, :node_not_in_cluster}
          | {:error, term()}
  def remove(node_name) when node_name == node(), do: {:error, :can_not_remove_self}
  def remove(node_name) when is_atom(node_name), do: Lib.remove_from_cluster(node_name)

  defdelegate status, to: Lib
  defdelegate all_nodes, to: Lib
  defdelegate running_nodes, to: Lib
  defdelegate not_running_nodes, to: Lib

  @doc """
  Check one node if running.
  """
  @spec is_running?(node()) :: boolean()
  if Mix.env() in [:test] do
    def is_running?(_node_name), do: true
  else
    def is_running?(node_name) do
      case :rpc.call(node_name, :erlang, :whereis, [__MODULE__]) do
        pid when is_pid(pid) -> true
        _ -> false
      end
    end
  end

  @doc """
  check ont node if in one cluster.
  """
  @spec is_clustered?(node) :: boolean()
  def is_clustered?(node_name) do
    Enum.member?(Lib.running_nodes(), node_name)
  end

  defdelegate check_cache_before(operate_mod, operate_func, operate_args, cache_opts), to: Cache

  # __end_of_module__
end
