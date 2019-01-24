defmodule Mcc.Model.Builder do
  @moduledoc """
  Mnesia module build helper.
  """

  import Kernel, except: [defstruct: 1]

  @extra_fields [:__cache_time__, :__expire_time__]

  defmacro defstruct(fields, if_extra \\ false) do
    record_fields =
      if_extra
      |> append_extra_fields(fields)
      |> Enum.map(fn
        {key, _default_value} -> key
        key -> key
      end)
      |> Enum.uniq()

    quote do
      Kernel.defstruct(unquote(record_fields))
      @fields unquote(record_fields)
    end
  end

  @doc false
  defp append_extra_fields(false, fields), do: fields
  defp append_extra_fields(true, fields), do: fields ++ @extra_fields

  # __end_of_module__
end
