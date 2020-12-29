defmodule Eventbus.Queue do
  @moduledoc """
  Queue implementation using Redis
  """

  alias Eventbus.{Queue, Redix}

  defstruct name: nil

  def queue(name) do
    project = System.get_env("PROJECT")
    if project do
      "#{project}:queue:#{name}"
    else
      "queue:#{name}"
    end
  end

  def init(name) do
    {:ok, %Queue{name: queue(name)}}
  end

  def reset(queue) do
    case Redix.command(:redix_pool, ["DEL", queue.name]) do
      {:ok, _} -> :ok
      error -> {:error, error}
    end
  end

  def count(queue) do
    count(:redix_pool, queue)
  end

  def count(redis, queue) do
    case Redix.command(redis, ["LLEN", queue.name]) do
      {:ok, val} -> {:ok, val}
      error -> {:error, error}
    end
  end

  def push(queue, val) do
    case Redix.command(:redix_pool, ["LPUSH", queue.name, val]) do
      {:ok, 0} -> :ok
      {:ok, _} -> :ok
      error -> {:error, error}
    end
  end

  def pop(queue) do
    case Redix.command(:redix_pool, ["RPOP", queue.name]) do
      {:ok, nil} -> {:ok, :empty}
      {:ok, val} -> {:ok, val}
      error -> {:error, error}
    end
  end

end
