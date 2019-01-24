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

  def remove_expiration_worker(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def children do
    DynamicSupervisor.which_children(__MODULE__)
  end

  def count_children do
    DynamicSupervisor.count_children(__MODULE__)
  end

  #
end
