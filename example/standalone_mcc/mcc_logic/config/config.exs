use Mix.Config

mcc_store_node_list =
  case System.get_env("MCC_STORE_NODE_LIST") do
    nil ->
      []

    node_list_string ->
      # "mcc_store_1,mcc_store_2;mcc_store_3,mcc_store_4"
      node_list_string
      |> String.split(";")
      |> Enum.with_index(1)
      |> Enum.map(fn {v, k} ->
        v =
          v
          |> String.split(",")
          |> Enum.map(fn i -> String.to_atom(i) end)

        {k, v}
      end)
  end

config :mcc,
  start_mcc: false

config :mcc_logic,
  mcc_store_node_list: mcc_store_node_list
