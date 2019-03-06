defmodule MccTest.Support.Node do
  @moduledoc false

  alias Porcelain.Process, as: Proc
  require Logger

  def start(name) when is_atom(name) do
    Application.ensure_started(:porcelain)
    "mcc_test_master@" <> hostname = "#{Node.self()}"
    node_name = :"#{name}@#{hostname}"
    node_pid = start_node_pid(:"#{name}", node_name)
    :ok = block_until_nodeup(node_pid)
    {:ok, _} = :rpc.call(node(), Application, :ensure_all_started, [:elixir])
    {:ok, _} = :rpc.call(node_name, Application, :ensure_all_started, [:logger])
    {:ok, node_name, node_pid}
  end

  def stop(name) when is_atom(name) do
    :abcast = :rpc.eval_everywhere([name], :init, :stop, [])
  end

  def start_and_register_guard do
    Mcc.start()
    Mcc.register_guard()

    receive do
      :kk ->
        :ok
    end
  end

  defp start_node_pid(snode_name, node_name) do
    spawn_link(fn ->
      Process.flag(:trap_exit, true)
      code_paths = :code.get_path()

      base_args = [
        "-noshell",
        "-sname #{snode_name}",
        "-setcookie 'mcc_test'",
        "-eval 'io:format(\"ok\", []).'"
      ]

      args =
        Enum.reduce(code_paths, Enum.join(base_args, " "), fn path, acc ->
          acc <> " -pa #{path}"
        end)

      %Proc{pid: pid} = Porcelain.spawn_shell("erl " <> args, in: :receive, out: {:send, self()})

      :ok = wait_until_started(node_name, pid)
      true = :net_kernel.connect_node(node_name)
      receive_loop(node_name, pid)
    end)
  end

  defp block_until_nodeup(pid) do
    case GenServer.call(pid, :ready) do
      true ->
        :ok

      false ->
        block_until_nodeup(pid)
    end
  end

  defp wait_until_started(node_name, pid) do
    receive do
      {^pid, :data, :out, _data} ->
        :ok

      {^pid, :result, %{status: status}} ->
        {:error, status}

      {:"$gen_call", from, :ready} ->
        GenServer.reply(from, false)
        wait_until_started(node_name, pid)
    end
  end

  defp receive_loop(node_name, pid) do
    receive do
      {^pid, :data, :out, data} ->
        case Application.get_env(:logger, :level, :warn) do
          l when l in [:debug, :info] ->
            IO.puts("#{node_name} =>\n" <> data)

          _ ->
            :ok
        end

        receive_loop(node_name, pid)

      {^pid, :result, %{status: status}} ->
        IO.puts("node_name: #{node_name}, status : #{status}")

      {:EXIT, parent, reason} when parent == self() ->
        Process.exit(pid, reason)

      {:"$gen_call", from, :ready} ->
        GenServer.reply(from, true)
        receive_loop(node_name, pid)

      :die ->
        Process.exit(pid, :normal)
    end
  end
end
