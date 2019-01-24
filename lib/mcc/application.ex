defmodule Mcc.Application do
  @moduledoc false

  use Application

  alias Mcc.Expiration.Supervisor, as: ExpSup

  # alias Mcc.

  def start(_type, _args) do
    Mcc.start()
    Mcc.register_guard()
    join_cluster()
    children = [{ExpSup, strategy: :one_for_one, name: ExpSup}]
    opts = [strategy: :one_for_one, name: Mcc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc false
  defp join_cluster do
    :kernel
    |> Application.get_env(:sync_nodes_optional, [])
    |> intersection(Node.list())
    |> case do
      [] ->
        :ok

      node_list ->
        [target_node | _] = Enum.sort(node_list)
        :ok = ensure_target_running(target_node)

        case Mcc.join(target_node) do
          :ok -> :ok
          {:error, {:already_clustered, _}} -> :ok
        end
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
  defp ensure_target_running(target_node) do
    if Mcc.is_running?(target_node) do
      true
    else
      Process.sleep(300)
      ensure_target_running(target_node)
    end
  end

  # __end_of_module__
end
