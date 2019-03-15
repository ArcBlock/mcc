use Mix.Config

env_cache_data_dir = System.get_env("CACHE_DATA_DIR") || "/"
{:ok, hostname} = :inet.gethostname()
cache_data_dir = Path.join([env_cache_data_dir, "#{hostname}/"])

config :mnesia,
  dir: String.to_charlist(cache_data_dir)

config :mcc,
  start_mcc: true,
  mnesia_table_modules: [MccStore]

sync_nodes_optional =
  case System.get_env("KERNEL_OPTIONAL_NODES") do
    nil ->
      []

    node_list_string when is_bitstring(node_list_string) ->
      node_list_string
      |> String.split(",")
      |> Enum.map(fn i -> String.to_atom(i) end)
  end

config :kernel,
  sync_nodes_optional: sync_nodes_optional
