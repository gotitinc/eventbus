defmodule Stats.Supervisor do
  @moduledoc """
  Stats supervisor
  """
  use Supervisor

  def start_link(table) do
    Supervisor.start_link(__MODULE__, [table], name: __MODULE__)
  end

  def init([table]) do
    children = []

    # create ETS
    ^table = :ets.new(table, [:set, :named_table, :public,
                          read_concurrency: true, write_concurrency: true])
    Supervisor.init(children, strategy: :one_for_one)
  end

end
