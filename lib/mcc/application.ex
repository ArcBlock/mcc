defmodule Mcc.Application do
  @moduledoc false

  use Application
  require Logger
  alias Mcc.Expiration.Supervisor, as: ExpSup
  alias Mcc.Lib

  # alias Mcc.

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Mcc.Supervisor]

    case Application.get_env(:mcc, :start_mcc, true) do
      true ->
        Mcc.start()
        Mcc.register_guard()
        join_cluster()
        children = [{ExpSup, strategy: :one_for_one, name: ExpSup}]
        Supervisor.start_link(children, opts)

      false ->
        Supervisor.start_link([], opts)
    end
  end

  @doc false
  defp join_cluster do
    :kernel
    |> Application.get_env(:sync_nodes_optional, [])
    |> try_connect_nodes()
    |> intersection(Node.list())
    |> case do
      [] ->
        Logger.warn("[mcc] #{node()} can't find any other nodes")
        :ok

      node_list ->
        [target_node | _] = Enum.sort(node_list)
        true = ensure_target_running?(target_node)

        case Mcc.join(target_node) do
          :ok -> Logger.info("[mcc] #{node()} joined in target node #{target_node}")
          {:error, {:already_clustered, _}} -> nil
        end

        Logger.info("[mcc] current cluster node list: #{inspect(Lib.status())}")
    end
  end

  @doc false
  defp intersection(list_1, list_2) do
    list_1
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(list_2))
    |> MapSet.to_list()
  end

  @doc false
  defp ensure_target_running?(target_node) do
    if Mcc.is_running?(target_node) do
      true
    else
      Process.sleep(300)
      ensure_target_running?(target_node)
    end
  end

  @doc false
  defp try_connect_nodes(node_list) do
    node_list
    |> Enum.map(fn node ->
      _ = Node.connect(node)
      node
    end)
  end

  # __end_of_module__
end
