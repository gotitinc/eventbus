defmodule Stats do
  @moduledoc """
  Stats Module
  """

  @table :stats_table

  def create(:counter, name, topic, partition) do
    :ets.insert(@table, {key(:counter, name, topic, partition), empty(:counter)})
  end
  def create(:latency, name, topic, partition) do
    key = key(:latency, name, topic, partition)
    entry =  empty(:latency)
    :ets.insert(@table, {key, entry})
  end

  def reset_all() do
    :ets.delete_all_objects(@table)
  end

  def reset(counter, name, topic, partition) do
    create(counter, name, topic, partition)
  end

  def increment(:counter, name, topic, partition, value \\ 1) do
    key = key(:counter, name, topic, partition)
    :ets.update_counter(@table, key, value, {key, 0})
    cond do
      name == :queue_in ->
        queue_key = key(:counter, :queue, topic, partition)
        :ets.update_counter(@table, queue_key, value, {key, 0})
      name == :queue_out ->
        queue_key = key(:counter, :queue, topic, partition)
        :ets.update_counter(@table, queue_key, -value, {key, 0})
      name == :delayed_in ->
        queue_key = key(:counter, :delayed, topic, partition)
        :ets.update_counter(@table, queue_key, value, {key, 0})
      name == :delayed_out ->
        queue_key = key(:counter, :delayed, topic, partition)
        :ets.update_counter(@table, queue_key, -value, {key, 0})
      true -> nil
    end
    true
  end

  def get(counter_type, name, topic, partition) do
    key = key(counter_type, name, topic, partition)
    case :ets.lookup(@table, key) do
      [{^key, val}] -> val
      _ ->  empty(counter_type)
    end
  end

  def empty(:counter), do: 0
  def empty(:latency), do: %{
    min: -1,
    max: -1,
    _smaller_10: 0,
    _10_100: 0,
    _100_1k: 0,
    _1k_10k: 0,
    _larger_10k: 0
  }

  def reset_many(:counter, name, topic, partitions) do
    partitions
    |> Enum.each(fn partition ->
      reset(:counter, name, topic, partition)
    end)
  end
  def reset_many(:latency, name, topic, partitions) do
    partitions
    |> Enum.each(fn partition ->
      reset(:latency, name, topic, partition)
    end)
  end

  def get_many(:counter, name, topic, partitions) do
    partitions
    |> Enum.reduce(0, fn partition, acc ->
      acc + get(:counter, name, topic, partition)
    end)
  end
  def get_many(:latency, name, topic, partitions) do
    partitions
    |> Enum.reduce(empty(:latency), fn partition, acc ->
      entry = get(:latency, name, topic, partition)
      acc
      |> (fn acc ->
        if acc[:min] == -1 or entry[:min] < acc[:min] do
          Map.put(acc, :min, entry[:min])
        else
          acc
        end
      end).()
      |> (fn acc ->
        if acc[:max] == -1 or entry[:max] > acc[:max] do
          Map.put(acc, :max, entry[:max])
        else
          acc
        end
      end).()
      |> (fn acc ->
        %{
          acc |
          _smaller_10: acc[:_smaller_10] + entry[:_smaller_10],
          _10_100: acc[:_10_100] + entry[:_10_100],
          _100_1k: acc[:_100_1k] + entry[:_100_1k],
          _1k_10k: acc[:_1k_10k] + entry[:_1k_10k],
          _larger_10k: acc[:_larger_10k] + entry[:_larger_10k]
        }
      end).()
    end)
  end

  def report(:latency, name, topic, partition, value) do
    key = key(:latency, name, topic, partition)
    entry = :ets.lookup(@table, key)
    |> case do
      [{^key, val}] when is_map(val) -> val
      _ ->  %{
        min: -1,
        max: -1,
        _smaller_10: 0,
        _10_100: 0,
        _100_1k: 0,
        _1k_10k: 0,
        _larger_10k: 0
      }
    end
    |> update_min(value)
    |> update_max(value)
    |> update_buckets(value)
    :ets.insert(@table, {key, entry})
  end

  defp update_min(entry, value) do
    if entry[:min] == -1 or value < entry[:min] do
      Map.put(entry, :min, value)
    else
      entry
    end
  end

  defp update_max(entry, value) do
    if entry[:max] == -1 or value > entry[:max] do
      Map.put(entry, :max, value)
    else
      entry
    end
  end

  defp update_buckets(entry, value) do
    cond do
      value < 10 ->
        Map.put(entry, :_smaller_10, entry[:_smaller_10] + 1)
      value < 100 ->
        Map.put(entry, :_10_100, entry[:_10_100] + 1)
      value < 1_000 ->
        Map.put(entry, :_100_1k, entry[:_100_1k] + 1)
      value < 10_000 ->
        Map.put(entry, :_1k_10k, entry[:_1k_10k] + 1)
      true ->
        Map.put(entry, :_larger_10k, entry[:_larger_10k] + 1)
    end
  end

  defp key(counter_type, name, topic, partition) do
    cond do
      is_bitstring(partition) ->
        {counter_type, name, topic, String.to_integer(partition)}
      is_integer(partition) ->
        {counter_type, name, topic, partition}
      true ->
        {counter_type, name, topic, 0}
    end
  end

end
