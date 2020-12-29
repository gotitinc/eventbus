defmodule Eventbus.JobSend do
  @moduledoc """
  A job that sends a payload to a process
  """
  alias __MODULE__
  alias Eventbus.Utils
  require Logger
  @derive {Poison.Encoder, only: [:job_id, :ts, :notifee, :payload, :topic, :partition, :__struct__]}

  defstruct job_id: nil,
            ts: 0,
            notifee: nil,
            payload: nil,
            topic: "send",
            partition: 0

  def init(payload, topic, partition, pid) do
    notifee = :erlang.pid_to_list(pid)
    %JobSend{job_id: UUID.uuid4(), ts: Utils.now(), notifee: notifee, payload: payload, topic: topic, partition: partition}
  end

  def call(%JobSend{} = job) do
    pid = job.notifee
    |> :erlang.list_to_pid
    send pid, job.payload
  end
end

defimpl Eventbus.Job, for: Eventbus.JobSend do
  def call(job), do: Eventbus.JobSend.call(job)
end
