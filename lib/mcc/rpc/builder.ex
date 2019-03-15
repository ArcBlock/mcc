defmodule Mcc.Rpc.Builder do
  @moduledoc """
  Macro for building RPC easily
  """

  defmacro rpc(operation) do
    {operation_name, o_1, operation_params} = operation
    new_operation = {String.to_atom("rpc_#{operation_name}"), o_1, operation_params}

    quote do
      def unquote(new_operation) do
        params = unquote(operation_params)
        operation_name = unquote(operation_name)
        retry_rpc(operation_name, params)
      end
    end
  end

  # __end_of_module__
end
