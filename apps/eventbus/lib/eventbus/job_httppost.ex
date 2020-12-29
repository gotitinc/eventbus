defmodule Eventbus.JobHttpPost do
  @moduledoc """
  Executes a post http call
  """
  alias __MODULE__
  alias Eventbus.{PartitionTimer, Utils}
  require Logger
  @derive {Poison.Encoder, only: [:job_id, :ts, :url, :payload, :topic,
              :partition, :retry, :max_retry, :timeout, :__struct__]}

  defstruct job_id: nil,
            ts: 0,
            url: nil,
            payload: nil,
            topic: nil,
            partition: nil,
            retry: 0,
            max_retry: nil,
            timeout: nil

  def init(payload, url, topic, partition, max_retry, timeout) do
    %JobHttpPost{job_id: UUID.uuid4(),
                 ts: Utils.now(),
                 url: url,
                 payload: payload,
                 topic: topic,
                 partition: partition,
                 max_retry: max_retry,
                 timeout: timeout}
  end

  def call(%JobHttpPost{} = job) do
    headers = [{"Content-type", "application/octet-stream"}]
    Stats.increment(:counter, :http_start, job.topic, job.partition)
    now = Utils.now()
    payload = case job.payload do
      %{} -> Poison.encode!(job.payload)
      term when is_list(term) -> Poison.encode!(job.payload)
      term when is_binary(term) -> term
      _ -> inspect(job.payload)
    end
    timeout = Map.get(job, :timeout) || 30_000
    case HTTPoison.post(job.url, payload, headers, hackney: [pool: :eb_pool, timeout: timeout, recv_timeout: timeout]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        latency = Utils.now() - now
        Stats.report(:latency, :http, job.topic, job.partition, latency)
        Stats.increment(:counter, :http_succeded, job.topic, job.partition)
        Logger.info(fn -> "HTTP latency: #{latency} topic: #{inspect job.topic} partition: #{inspect job.partition} url: #{inspect job.url}" end)
        {:ok, body}
      error ->
        Stats.increment(:counter, :http_error, job.topic, job.partition)
        Logger.error(fn -> "Eventbus.JobHttpPost(#{inspect(self())}) retry: #{job.retry} url: #{inspect job.url} payload: #{inspect job.payload} error: #{inspect(error)}" end)
        handle_error(job)
        {:error, error}
    end
  end

  def handle_error(%JobHttpPost{retry: retry} = job) do
    max_retry = Map.get(job, :max_retry) || Application.get_env(:eventbus, :max_retry, 5)
    if retry < max_retry do
      timeout = Utils.now() + (job.retry + 1) * 1_000
      Stats.increment(:counter, :http_retry, job.topic, job.partition)
      job = Map.put(job, :retry, job.retry + 1)

      PartitionTimer.post_delayed_job(job.topic, job.partition, job, timeout)
    end
  end
end

defimpl Eventbus.Job, for: Eventbus.JobHttpPost do
  def call(job), do: Eventbus.JobHttpPost.call(job)
end
