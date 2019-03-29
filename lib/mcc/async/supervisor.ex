defmodule Mcc.Async.Supervisor do
  @moduledoc """
  Supervise the async writer.
  """

  use Supervisor
  alias Mcc.Async.Writer

  def writer_num do
    Application.get_env(:mcc, :async_writer_num, System.schedulers_online())
  end

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    async_writer_list =
      for id_num <- 0..(writer_num() - 1) do
        id = String.to_atom("#{Writer}_#{id_num}")
        %{id: id, start: {Writer, :start_link, [id]}}
      end

    Supervisor.init(async_writer_list, strategy: :one_for_one)
  end

  # __end_of_module__
end
