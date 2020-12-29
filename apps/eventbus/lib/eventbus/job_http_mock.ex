defmodule Eventbus.JobHttpMock do
  @moduledoc """
  A job that mocks an http send but instead sends parameters to a process
  """
  alias __MODULE__
  alias Eventbus.Utils
  require Logger
  @derive {Poison.Encoder, only: [:job_id, :ts, :notifee, :payload, :url,
      :topic, :partition, :max_retry, :timeout, :__struct__]}

  defstruct job_id: nil,
            ts: 0,
            notifee: nil,
            payload: nil,
            url: nil,
            topic: nil,
            partition: 0,
            max_retry: nil,
            timeout: nil

  def init(params, url, topic, partition, max_retry, timeout) do
    {payload, pid} = params
    notifee = :erlang.pid_to_list(pid)
    %JobHttpMock{job_id: UUID.uuid4(), ts: Utils.now(), notifee: notifee,
                payload: payload, url: url, topic: topic, partition: partition,
                max_retry: max_retry, timeout: timeout}
  end

  def call(%JobHttpMock{} = job) do
    pid = job.notifee
    |> :erlang.list_to_pid
    send pid, {job.payload, job.url, job.topic, job.partition}
  end
end

defimpl Eventbus.Job, for: Eventbus.JobHttpMock do
  def call(job), do: Eventbus.JobHttpMock.call(job)
end
