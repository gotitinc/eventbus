defmodule Stats.Application do
  @moduledoc """
  The Stats Application Service.
  """
  use Application

  def start(_type, _args) do
    Stats.Supervisor.start_link(:stats_table)
  end
end
