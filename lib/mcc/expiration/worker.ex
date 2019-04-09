defmodule Mcc.Expiration.Worker do
  @moduledoc """
  Expiration worker for each mnesia cluster table.
  """

  use GenServer

  require Logger

  def start_link(worker_name, worker_opts) do
    GenServer.start_link(__MODULE__, worker_opts, name: worker_name)
  end

  def init(worker_opts) do
    check_interval = Keyword.get(worker_opts, :check_interval, 1_000)
    scheduler(check_interval)
    main_tab = Keyword.fetch!(worker_opts, :main_table)
    _ = Logger.info("[mcc] the expiration process for #{main_tab} started")

    {:ok,
     %{
       main_tab: main_tab,
       main_mod: Keyword.get(worker_opts, :main_module),
       exp_tab: Keyword.fetch!(worker_opts, :expiration_table),
       exp_mod: Keyword.get(worker_opts, :expiration_module),
       size_limit: Keyword.get(worker_opts, :size_limit, 1_000_000),
       memory_limit: Keyword.get(worker_opts, :memory_limit, 100),
       waterline_ratio: Keyword.get(worker_opts, :waterline_ratio, 0.7),
       check_interval: check_interval
     }}
  end

  def handle_info(
        :tick,
        %{
          main_mod: main_mod,
          main_tab: main_tab,
          exp_mod: exp_mod,
          exp_tab: exp_tab,
          size_limit: size_limit,
          memory_limit: memory_limit,
          waterline_ratio: waterline_ratio,
          check_interval: check_interval
        } = state
      ) do
    clean_table_ttl(first_key(exp_mod, exp_tab), {exp_mod, exp_tab}, {main_mod, main_tab})
    clean_table_size({exp_mod, exp_tab}, {main_mod, main_tab}, size_limit, waterline_ratio)
    clean_table_memory({exp_mod, exp_tab}, {main_mod, main_tab}, memory_limit, waterline_ratio)
    scheduler(check_interval)
    {:noreply, state}
  end

  @doc false
  defp clean_table_ttl(:"$end_of_table", _, _) do
    :ok
  end

  defp clean_table_ttl({expire_time, main_key} = key, {exp_mod, exp_tab}, {main_mod, main_tab}) do
    if DateTime.to_unix(DateTime.utc_now()) > expire_time do
      :ok = delete_key(exp_mod, exp_tab, key)
      :ok = delete_key(main_mod, main_tab, main_key)
      clean_table_ttl(first_key(exp_mod, exp_tab), {exp_mod, exp_tab}, {main_mod, main_tab})
    else
      :ok
    end
  end

  @doc false
  defp clean_table_size({exp_mod, exp_tab}, {main_mod, main_tab}, size_limit, waterline_ratio) do
    if table_info(main_mod, main_tab, :size) >= size_limit do
      size_waterline = round(size_limit * waterline_ratio)
      first_key = first_key(exp_mod, exp_tab)
      clean_limit(first_key, :size, {exp_mod, exp_tab}, {main_mod, main_tab}, size_waterline)
    end
  end

  @doc false
  defp clean_table_memory(
         {exp_mod, exp_tab},
         {main_mod, main_tab},
         memory_limit,
         waterline_ratio
       ) do
    memory_limit = round(memory_limit * 1024 * 1024 / :erlang.system_info(:wordsize))
    mem_waterline = round(memory_limit * waterline_ratio)

    if table_info(main_mod, main_tab, :memory) >= memory_limit do
      first_key = first_key(exp_mod, exp_tab)
      clean_limit(first_key, :memory, {exp_mod, exp_tab}, {main_mod, main_tab}, mem_waterline)
    end
  end

  @doc false
  defp clean_limit(:"$end_of_table", _, _, _, _) do
    :ok
  end

  defp clean_limit(
         {_, main_key} = expire_key,
         tag,
         {exp_mod, exp_tab},
         {main_mod, main_tab},
         limit
       ) do
    :ok = exp_tab.delete(expire_key)
    :ok = main_tab.delete(main_key)

    if table_info(main_mod, main_tab, tag) > limit do
      first_key = first_key(exp_mod, exp_tab)
      clean_limit(first_key, tag, {exp_mod, exp_tab}, {main_mod, main_tab}, limit)
    end
  end

  @doc false
  defp first_key(nil, exp_tab), do: exp_tab.first()
  defp first_key(exp_mod, exp_tab), do: exp_mod.first(exp_tab)

  @doc false
  defp delete_key(nil, tab, key), do: tab.delete(key)
  defp delete_key(mod, tab, key), do: mod.delete(tab, key)

  @doc false
  defp table_info(nil, table, info_key), do: table.table_info(info_key)
  defp table_info(mod, table, info_key), do: mod.table_info(table, info_key)

  @doc false
  defp scheduler(check_interval), do: Process.send_after(self(), :tick, check_interval)

  #
end
