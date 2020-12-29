defmodule Eventbus.PriorityQueue do
  @moduledoc """
  PriorityQueue implements a priority queue using REDIS sorted sets
  """
  alias Eventbus.{PriorityQueue, Redix}

  defstruct name: nil

  def queue(name) do
    project = System.get_env("PROJECT")
    if project do
      "#{project}:prio:#{name}"
    else
      "prio:#{name}"
    end

  end

  def init(name) do
    {:ok, %PriorityQueue{name: queue(name)}}
  end

  def reset(queue) do
    case Redix.command(:redix_pool, ["DEL", queue.name]) do
      {:ok, _} -> :ok
      error -> {:error, error}
    end
  end

  def count(queue, min, max) do
    case Redix.command(:redix_pool, ["ZCOUNT", queue.name, min, max]) do
      {:ok, val} -> {:ok, val}
      error -> {:error, error}
    end
  end

  def count(queue) do
    case Redix.command(:redix_pool, ["ZCOUNT", queue.name, "-inf", "+inf"]) do
      {:ok, val} -> {:ok, val}
      error -> {:error, error}
    end
  end

  def insert(queue, key, prio) do
    case Redix.command(:redix_pool, ["ZADD", queue.name, prio, key]) do
      {:ok, 0} -> :ok
      {:ok, 1} -> :ok
      error -> {:error, error}
    end
  end

  def remove(queue, key) do
    case Redix.command(:redix_pool, ["ZREM", queue.name, key]) do
      {:ok, 0} -> {:ok, :not_found}
      {:ok, 1} -> :ok
      error -> {:error, error}
    end
  end

  def first(queue) do
    case Redix.command(:redix_pool, ["ZRANGE", queue.name, "0", "0", "WITHSCORES"]) do
      {:ok, []} -> {:ok, :empty}
      {:ok, [key, prio]} -> {:ok, %{key: key, prio: String.to_integer(prio)}}
      error -> {:error, error}
    end
  end

  def last(queue) do
    case Redix.command(:redix_pool, ["ZRANGE", queue.name, "-1", "-1", "WITHSCORES"]) do
      {:ok, []} -> {:ok, :empty}
      {:ok, [key, prio]} -> {:ok, %{key: key, prio: String.to_integer(prio)}}
      error -> {:error, error}
    end
  end

end
