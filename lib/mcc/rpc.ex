defmodule Mcc.Rpc do
  @moduledoc """
  Macro for mcc rpc.
  """

  defmacro __using__(opts) do
    quote do
      import Mcc.Rpc.Builder

      @rpc_opts unquote(Macro.escape(opts))
      @before_compile unquote(__MODULE__)

      @doc """
      Retry for rpc remote operation.
      """
      def retry_rpc(operation_name, params) do
        retry_rpc_do(operation_name, params, get_retry_times())
      end

      @doc false
      defp retry_rpc_do(operation_name, params, retry_times, exclude_node \\ nil) do
        [params_key | _] = params
        target_node = get_target_node(params_key, exclude_node)
        timeout = get_timeout()

        case apply(:rpc, :call, [target_node, __MODULE__, operation_name, params, timeout]) do
          {:badrpc, _} when retry_times > 1 ->
            retry_rpc_do(operation_name, params, retry_times - 1, target_node)

          {:badrpc, _} = error ->
            :"$badrpc"

          res ->
            res
        end
      end

      @doc false
      defp get_target_node(key, exclude_node) do
        get_target_node(get_target_list(), key, exclude_node)
      end

      @doc false
      defp get_timeout do
        Keyword.get(@rpc_opts, :rpc_timeout, 5000)
      end

      @doc false
      defp get_retry_times do
        Keyword.get(@rpc_opts, :retry_times, 1)
      end

      @doc false
      defp get_target_node([{_, _} | _] = node_list, key, exclude_node) do
        length = Enum.count(node_list)
        hash = :erlang.phash2(key, length)
        get_target_node(Enum.at(node_list, hash), key, exclude_node)
      end

      defp get_target_node({_, node_list}, key, exclude_node) do
        get_target_node(node_list, key, exclude_node)
      end

      defp get_target_node([_ | _] = node_list, _, exclude_node) do
        node_list
        |> Enum.reject(fn i -> exclude_node == i end)
        |> case do
          [] -> exclude_node
          list -> Enum.random(list)
        end
      end

      # __end_of_macro__
    end
  end

  defmacro __before_compile__(%Macro.Env{module: module}) do
    rpc_opts = Module.get_attribute(module, :rpc_opts)

    quote do
      def get_target_list do
        Keyword.fetch!(unquote(rpc_opts), :target_list)
      end
    end
  end

  # __end_of_module__
end
