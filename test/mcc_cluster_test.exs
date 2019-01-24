defmodule MccClusterTest do
  use ExUnit.Case

  alias MccTest.Support.Node, as: SupportNode

  @tag :mcc_test
  setup_all do
    :rand.seed(:exs64)
    {:ok, _} = :net_kernel.start([:mcc_test_master, :shortnames])
    :mnesia.stop()
    Node.set_cookie(:mcc_test)
    :ok
  end

  @tag :mcc_test
  setup do
    {:ok, node1, _node1pid} = SupportNode.start(:a)
    {:ok, node2, _node2pid} = SupportNode.start(:b)
    {:ok, node3, _node3pid} = SupportNode.start(:c)

    on_exit(fn ->
      SupportNode.stop(node1)
      SupportNode.stop(node2)
      SupportNode.stop(node3)
    end)

    [nodes: [node1, node2, node3]]
  end

  @tag :mcc_test
  test "cluster management", %{nodes: [node1, node2, node3 | _]} do
    ensure_remote_app_has_correct_env(node1)
    start_and_register_guard(node1)
    ensure_remote_app_started(node1, :mnesia)
    ensure_remote_app_has_correct_env(node2)
    start_and_register_guard(node2)
    ensure_remote_app_started(node2, :mnesia)
    ensure_remote_app_has_correct_env(node3)
    start_and_register_guard(node3)
    ensure_remote_app_started(node3, :mnesia)

    # cluster join && get all nodes
    [^node1] = :rpc.call(node1, Mcc, :all_nodes, [])
    {:error, {:can_not_join_self, ^node1}} = :rpc.call(node1, Mcc, :join, [node1])
    :ok = :rpc.call(node2, Mcc, :join, [node1])
    {:error, {:already_clustered, ^node1}} = :rpc.call(node2, Mcc, :join, [node1])
    [^node1, ^node2] = :lists.sort(:rpc.call(node1, Mcc, :all_nodes, []))
    [^node1, ^node2] = :lists.sort(:rpc.call(node2, Mcc, :all_nodes, []))
    :ok = :rpc.call(node3, Mcc, :join, [node1])
    [^node1, ^node2, ^node3] = :lists.sort(:rpc.call(node1, Mcc, :all_nodes, []))
    [^node1, ^node2, ^node3] = :lists.sort(:rpc.call(node2, Mcc, :all_nodes, []))
    [^node1, ^node2, ^node3] = :lists.sort(:rpc.call(node3, Mcc, :all_nodes, []))

    ## get_running_nodes
    [^node1, ^node2, ^node3] = :lists.sort(:rpc.call(node1, Mcc, :running_nodes, []))

    ## remove node from the cluster
    {:error, :node_not_in_cluster} =
      :rpc.call(node1, Mcc, :remove, [String.to_atom("fake@localhost")])

    {:error, :can_not_remove_self} = :rpc.call(node1, Mcc, :remove, [node1])
    :ok = :rpc.call(node1, Mcc, :remove, [node3])
    [^node1, ^node2] = :lists.sort(:rpc.call(node1, Mcc, :all_nodes, []))
    [^node1, ^node2] = :lists.sort(:rpc.call(node2, Mcc, :all_nodes, []))

    ## leave from the cluster
    :ok = :rpc.call(node2, Mcc, :leave, [])
    [^node1] = :rpc.call(node1, Mcc, :all_nodes, [])

    ## rejoin node2
    :ok = :rpc.call(node2, Mcc, :join, [node1])
    [^node1, ^node2] = :lists.sort(:rpc.call(node1, Mcc, :all_nodes, []))
    [^node1, ^node2] = :lists.sort(:rpc.call(node2, Mcc, :all_nodes, []))

    :ok = :rpc.call(node2, Mcc, :leave, [])

    ## stop all nodes
    SupportNode.stop(node1)
    SupportNode.stop(node2)
    SupportNode.stop(node3)
  end

  def start_and_register_guard(node_param) do
    :rpc.call(node_param, :erlang, :apply, [
      :erlang,
      :spawn,
      [SupportNode, :start_and_register_guard, []]
    ])
  end

  def ensure_remote_app_started(node_param, app) do
    started_applications_list = :rpc.call(node_param, Application, :started_applications, [])

    case :lists.keyfind(app, 1, started_applications_list) do
      false ->
        Process.sleep(300)
        ensure_remote_app_started(node_param, app)

      {^app, _, _} ->
        :ok
    end
  end

  def ensure_remote_app_has_correct_env(node_param) do
    :rpc.call(node_param, Application, :put_env, [
      :mcc,
      :mnesia_table_modules,
      Application.get_env(:mcc, :mnesia_table_modules)
    ])
  end

  #
end
