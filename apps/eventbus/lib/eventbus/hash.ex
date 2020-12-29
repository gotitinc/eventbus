defmodule Eventbus.Hash do
  @moduledoc """
  Hash implements a map with REDIS using hashes
  """
  require Logger
  alias Eventbus.{Hash, Utils, Redix}

  defstruct name: nil

  def hash(name) do
    project = System.get_env("PROJECT")
    if project do
      "#{project}:hash:#{name}"
    else
      "hash:#{name}"
    end
  end

  def init(name) do
    {:ok, %Hash{name: hash(name)}}
  end

  def reset(map) do
    case Redix.command(:redix_pool, ["DEL", map.name]) do
      {:ok, _} -> :ok
      error -> {:error, error}
    end
  end

  def set(map, key, value) do
    case Redix.command(:redix_pool, ["HSET", map.name, key, Poison.encode!(value)]) do
      {:ok, 0} -> :ok
      {:ok, 1} -> :ok
      error -> {:error, error}
    end
  end

  def incr_by(map, key, value) do
    case Redix.command(:redix_pool, ["HINCRBY", map.name, key, value]) do
      {:ok, _} -> :ok
      error -> {:error, error}
    end
  end

  # Note: get assumes that the value is a structure
  def get(map, key) do
    case Redix.command(:redix_pool, ["HGET", map.name, key]) do
      {:ok, nil} -> {:ok, :not_found}
      {:ok, value} ->
        {:ok, (value
               |> Poison.decode!()
               |> Utils.to_struct())}
      error -> {:error, error}
    end
  end

  # Note: get assumes that the value is NOT a structure
  def get_all(map) do
    case Redix.command(:redix_pool, ["HGETALL", map.name]) do
      {:ok, nil} -> {:ok, :not_found}
      {:ok, res} ->
        {:ok, res
        |> Enum.chunk_every(2)
        |> Enum.map(fn [key, value] ->
            {key,
             value
              |> Poison.decode!()}
          end)
        |> Map.new}
      error -> {:error, error}
    end
  end

  def delete(map, key) do
    case Redix.command(:redix_pool, ["HDEL", map.name, key]) do
      {:ok, 0} -> {:ok, :not_found}
      {:ok, 1} -> :ok
      error -> {:error, error}
    end
  end

end
