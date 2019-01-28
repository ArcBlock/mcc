defmodule MccTest.Support.AccountFile do
  @moduledoc """
  Write account information into file.
  """

  @file_name "/tmp/mcc_test/support/account_file"

  def init_file do
    :filelib.ensure_dir(@file_name)

    data =
      for i <- 1..100 do
        "id_file_#{i}|info_file_#{i}\n"
      end

    File.write!(@file_name, data)
  end

  def get_account(id) do
    @file_name
    |> File.read!()
    |> String.split("\n")
    |> Enum.reject(fn i -> i == "" end)
    |> Enum.map(fn record ->
      [id, info] = String.split(record, "|")
      {id, info}
    end)
    |> Map.new()
    |> Map.get(id)
  end

  # __end_of_module__
end
