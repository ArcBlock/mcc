defmodule Mcc.Model.Repo do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :table_modules, accumulate: true)
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro import_table(module) do
    quote do
      @table_modules unquote(module)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def tables do
        for module <- @table_modules do
          module.table()
        end
      end
    end
  end

  # __end_of_module__
end
