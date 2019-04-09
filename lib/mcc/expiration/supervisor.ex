defmodule Mcc.Expiration.Supervisor do
  @moduledoc """
  Supervise the expiration worker for different mnesia cluster table.
  """
  use DynamicSupervisor

  alias Mcc.Expiration.Worker

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def add_expiration_worker(table, opts) do
    child_spec = %{
      id: table,
      start: {Worker, :start_link, [table, opts]}
    }

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, _} -> :ok
      {:ok, _, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      other -> {:error, other}
    end
  end

  # __end_of_module__
end
