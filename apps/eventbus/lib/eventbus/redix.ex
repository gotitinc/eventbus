defmodule Eventbus.Redix do
  @moduledoc """
  Manages Pool of Redix connections
  """
  @pool_size 4

  def child_spec(redis_url) do
    # Specs for the Redix connections.
    children =
      for i <- 0..(@pool_size - 1) do
        Supervisor.child_spec({Redix, {redis_url, [name: :"redix_#{i}"]}}, id: {Redix, i})
      end ++
      [Supervisor.child_spec({Redix, {redis_url, [name: :redix_stats]}}, id: {Redix, :stats})]

    # Spec for the supervisor that will supervise the Redix connections.
    %{
      id: RedixSupervisor,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
    }
  end

  def command(:redix_pool, command) do
    Redix.command(:"redix_#{random_index()}", command)
  end
  def command(redis, command) do
    Redix.command(redis, command)
  end

  defp random_index() do
    rem(System.unique_integer([:positive]), @pool_size)
  end
end
