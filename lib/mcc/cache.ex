defmodule Mcc.Cache do
  @moduledoc """
  Some functions about cache.
  """

  @doc """
  Check cache before operation.
  """
  @spec check_cache_before(atom(), atom(), [term()], Keyword.t()) :: term()
  def check_cache_before(operate_mod, operate_func, operate_args, cache_opts) do
    cache_mod = Keyword.fetch!(cache_opts, :cache_mod)
    read_cache_func = Keyword.fetch!(cache_opts, :read_cache_func)

    case apply(cache_mod, read_cache_func, get_cache_args(cache_opts)) do
      :"$not_can_found" ->
        data = apply(operate_mod, operate_func, operate_args)
        write_back(cache_opts, cache_mod, data)

      data ->
        data
    end
  end

  @doc false
  defp get_cache_args(cache_opts) do
    cache_key = Keyword.fetch!(cache_opts, :cache_key)

    case Keyword.get(cache_opts, :cache_ttl) do
      cache_ttl when is_integer(cache_ttl) -> [cache_key, cache_ttl]
      _ -> [cache_key]
    end
  end

  @doc false
  defp write_back(cache_opts, cache_mod, data) do
    if Keyword.get(cache_opts, :write_back, false) do
      write_cache_func = Keyword.fetch!(cache_opts, :write_cache_func)
      cache_key = Keyword.fetch!(cache_opts, :cache_key)

      case Keyword.get(cache_opts, :cache_ttl) do
        nil -> _ = apply(cache_mod, write_cache_func, [cache_key, data])
        cache_ttl -> _ = apply(cache_mod, write_cache_func, [cache_key, data, cache_ttl])
      end

      data
    else
      data
    end
  end
end
