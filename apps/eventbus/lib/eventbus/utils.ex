defmodule Eventbus.Utils do
  @moduledoc """
  Utility functions
  """
  require Logger

  def now() do
    :os.system_time(:milli_seconds)
  end

  def delay(time) do
    diff = time - now()
    if diff > 0, do: diff, else: 0
  end

  def to_struct(data) when is_map(data) do
    try do
      data |> Maptu.struct!()
    rescue
      error in ArgumentError ->
        Logger.error(fn -> "error to_struct(#{inspect data}): #{inspect error}" end)
        data
    end
  end
  def to_struct(data) do
    data
  end

  def env_to_topics_spec(nil), do: nil
  def env_to_topics_spec(json_topics) do
    try do
      with {:ok, topics} <- Poison.decode(json_topics) do
        topics |> Enum.flat_map(fn entry ->
          entry |> Map.to_list |> Enum.map(fn {topic, partitions} ->
              [topic: topic, partition_count: partitions]
          end)
        end)
      end
    rescue
      error ->
        Logger.error(fn -> "error #{inspect json_topics}: #{inspect error}" end)
        nil
    end
  end

end
