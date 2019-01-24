defmodule Mcc.Model do
  @moduledoc """
  mnesia wrapper.
  """

  defmacro __using__(_) do
    quote do
      use Mcc.Model.Repo

      alias Mcc.Expiration.Supervisor, as: ExpSup
      alias Mcc.Model

      @spec boot_tables() :: :ok
      def boot_tables do
        Enum.each(tables(), fn {table, attr} -> Model.create_table(table, attr) end)
      end

      @spec copy_tables() :: :ok
      def copy_tables do
        Enum.each(tables(), fn {table, attr} ->
          case {
            Keyword.has_key?(attr, :ram_copies),
            Keyword.has_key?(attr, :disc_copies),
            Keyword.has_key?(attr, :disc_only_copies)
          } do
            {true, false, false} -> Model.copy_table(table, :ram_copies)
            {false, true, false} -> Model.copy_table(table, :disc_copies)
            {false, false, true} -> Model.copy_table(table, :disc_only_copies)
          end
        end)

        :ok
      end

      @spec start_expiration_process :: :ok
      def start_expiration_process do
        Enum.each(tables(), fn {module, _} ->
          case apply(module, :get_expiration_opts, []) do
            [] -> nil
            expiration_opts -> ExpSup.add_expiration_worker(module, expiration_opts)
          end
        end)
      end

      # __end_of_macro__
    end
  end

  @doc """
  Copy mnesia table from remote node.
  """
  @spec copy_table(atom(), atom()) :: :ok | {:error, any()}
  def copy_table(name, ram_or_disc \\ :ram_copies) do
    ensure_table(:mnesia.add_table_copy(name, node(), ram_or_disc))
  end

  @doc """
  Create mnesia table.
  """
  @spec create_table(atom(), atom()) :: :ok | {:error, any()}
  def create_table(name, tab_def) do
    :ok = ensure_table(:mnesia.create_table(name, tab_def))
  end

  @doc false
  defp ensure_table({:atomic, :ok}), do: :ok
  defp ensure_table({:aborted, {:already_exists, _}}), do: :ok
  defp ensure_table({:aborted, {:already_exists, _name, _node_name}}), do: :ok
  defp ensure_table({:aborted, error}), do: {:error, error}

  # __end_of_module__
end
