defmodule Eventbus.JobHttpPostTest do
  use ExUnit.Case
  alias Eventbus.{Job, JobHttpPost}

  @topic "topic"
  @partition 0
  @max_retry 5
  @timeout 20_000

  test "create remote job" do
    job = JobHttpPost.init("payload", "http://example.com", @topic, @partition,
            @max_retry, @timeout)
    assert job ==
          %JobHttpPost{job_id: job.job_id, url: "http://example.com", payload: "payload",
                       topic: @topic, partition: @partition, ts: job.ts,
                       max_retry: @max_retry, timeout: @timeout}
  end

  @tag :remote
  test "call remote job" do
    job = JobHttpPost.init("payload", "http://httpbin.org/post",
                           @topic, @partition, @max_retry, @timeout)
    {:ok, resp} = Job.call(job)
    resp_map = Poison.decode!(resp)
    assert resp_map["data"] == "payload"
  end
end
