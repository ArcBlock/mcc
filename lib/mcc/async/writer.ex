defmodule Mcc.Async.Writer do
  @moduledoc """
  Async writer module.

  The writer is a group of `GenServer` process, which support write mcc cache
  table asynchronously.

  Why we need the module?

  As we all know, in general, the write operations are heavy, especially if
  using transaction to write cache. Rely on async writer, the upper application
  can get the data from source database and retrun as soon as possible rather
  than wait for the write operation to complete.
  When async write, this module will dispatch the keys to different `GenServer`
  process depend on hash of key. So that, the async writer will avoid the single
  point from the `GenServer` process.
  """

  use GenServer
  alias Mcc.Async.Supervisor

  @doc """
  Async put operation.

  This function support upper application write the cache table using async
  approach, and the key will be dispatched to different `GenServer` process
  depend on hash of the `key`.
  """
  @spec put(any, module, function, [any]) :: :ok
  def put(key, mod, func, args) do
    writer_index = :erlang.phash2(key, Supervisor.writer_num())
    writer_name = String.to_atom("#{__MODULE__}_#{writer_index}")
    GenServer.cast(writer_name, {:put, mod, func, args})
  end

  @doc """
  Start the `GenServer` process and link it.
  """
  @spec start_link(atom) :: GenServer.on_start()
  def start_link(id) do
    GenServer.start_link(__MODULE__, nil, name: id)
  end

  # callback
  def init(_) do
    {:ok, %{}}
  end

  # callback
  def handle_cast({:put, mod, func, args}, state) do
    _ = apply(mod, func, args)
    {:noreply, state}
  end

  # __end_of_module__
end
