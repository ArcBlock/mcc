defmodule Mcc.Model.Repo do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :table_modules, accumulate: true)
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro import_table(module, options \\ []) do
    case Keyword.get(options, :table_name) do
      nil ->
        quote do
          @table_modules unquote(module)
        end

      table_name ->
        quote do
          @table_modules {unquote(module), unquote(table_name)}
        end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def tables do
        for table_module <- @table_modules do
          case table_module do
            {module, table_name} -> module.table(table_name)
            module -> module.table()
          end
        end
      end
    end
  end

  # __end_of_module__
end
