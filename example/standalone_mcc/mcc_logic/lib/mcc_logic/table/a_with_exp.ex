defmodule MccStore.Table.AWithExp do
  @moduledoc false

  use Mcc.Rpc,
    target_list: Application.get_env(:mcc_logic, :mcc_store_node_list, []),
    retry_times: 3,
    rpc_timeout: 5000

  rpc(get_with_ttl(k))
  rpc(get_with_ttl(k, ttl))

  rpc(put_with_ttl(k, v))
  rpc(put_with_ttl(k, v, ttl))

  rpc(sync_dirty_put(k, v))
  rpc(sync_dirty_put(k, v, ttl))

  # __end_of_module__
end
