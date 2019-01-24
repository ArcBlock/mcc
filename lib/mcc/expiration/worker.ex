defmodule Mcc.Expiration.Worker do
  @moduledoc """
  Expiration worker for each mnesia cluster table.
  """

  use GenServer

  def start_link(worker_name, worker_opts) do
    GenServer.start_link(__MODULE__, worker_opts, name: worker_name)
  end

  def init(worker_opts) do
    check_interval = Keyword.get(worker_opts, :check_interval, 1_000)
    scheduler(check_interval)

    {:ok,
     %{
       main_tab: Keyword.fetch!(worker_opts, :main_table),
       exp_tab: Keyword.fetch!(worker_opts, :expiration_table),
       size_limit: Keyword.get(worker_opts, :size_limit, 1_000_000),
       memory_limit: Keyword.get(worker_opts, :memory_limit, 100),
       waterline_ratio: Keyword.get(worker_opts, :waterline_ratio, 0.7),
       check_interval: check_interval
     }}
  end

  def handle_info(
        :tick,
        %{
          main_tab: main_tab,
          exp_tab: exp_tab,
          size_limit: size_limit,
          memory_limit: memory_limit,
          waterline_ratio: waterline_ratio,
          check_interval: check_interval
        } = state
      ) do
    clean_table_via_ttl(exp_tab.first(), exp_tab, main_tab)
    clean_table_via_size_limit(exp_tab, main_tab, size_limit, waterline_ratio)
    clean_table_via_memory_limit(exp_tab, main_tab, memory_limit, waterline_ratio)
    scheduler(check_interval)
    {:noreply, state}
  end

  @doc false
  defp clean_table_via_ttl(:"$end_of_table", _, _) do
    :ok
  end

  defp clean_table_via_ttl({expire_time, main_key} = key, exp_tab, main_tab) do
    if DateTime.to_unix(DateTime.utc_now()) > expire_time do
      :ok = exp_tab.delete(key)
      :ok = main_tab.delete(main_key)
      clean_table_via_ttl(exp_tab.first(), exp_tab, main_tab)
    else
      :ok
    end
  end

  @doc false
  defp clean_table_via_size_limit(exp_tab, main_tab, size_limit, waterline_ratio) do
    if main_tab.table_info(:size) >= size_limit do
      size_waterline = round(size_limit * waterline_ratio)
      clean_table_via_limit(exp_tab.first(), :size, exp_tab, main_tab, size_waterline)
    end
  end

  @doc false
  defp clean_table_via_memory_limit(exp_tab, main_tab, memory_limit, waterline_ratio) do
    memory_limit = round(memory_limit * 1024 * 1024 / 8)
    mem_waterline = round(memory_limit * waterline_ratio)

    if main_tab.table_info(:memory) >= memory_limit do
      clean_table_via_limit(exp_tab.first(), :memory, exp_tab, main_tab, mem_waterline)
    end
  end

  @doc false
  defp clean_table_via_limit(:"$end_of_table", _, _, _, _) do
    :ok
  end

  defp clean_table_via_limit({_, main_key} = expire_key, tag, exp_tab, main_tab, limit) do
    :ok = exp_tab.delete(expire_key)
    :ok = main_tab.delete(main_key)

    if main_tab.table_info(tag) > limit do
      clean_table_via_limit(exp_tab.first(), tag, exp_tab, main_tab, limit)
    end
  end

  @doc false
  defp scheduler(check_interval), do: Process.send_after(self(), :tick, check_interval)

  #
end
