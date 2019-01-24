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

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  # __end_of_module__
end
