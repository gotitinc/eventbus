defmodule Eventbus.UtilsTest do
  use ExUnit.Case
  alias Eventbus.Utils

  test "now returns the current time in milli_seconds" do
    prior_ts = :os.system_time(:milli_seconds)
    now = Utils.now()
    posterior_ts = :os.system_time(:milli_seconds)
    assert now > 0
    assert prior_ts <= now
    assert now <= posterior_ts
  end

  test "delay return 0 if in the past" do
    now = Utils.now()
    assert Utils.delay(now) == 0
    assert Utils.delay(now - 10) == 0
  end

  test "delay returns >0 if in the future" do
    now = Utils.now()
    assert Utils.delay(now + 1000) > 0
    assert Utils.delay(now + 1000) <= 1000
  end

  test "nil topics env returns nil" do
    assert is_nil Utils.env_to_topics_spec(nil)
  end

  test "invalid topics env returns nil" do
    topic_env = ~s({"router": 200})
    assert is_nil Utils.env_to_topics_spec(topic_env)
  end

  test "one entry json topic returns topic spec" do
    topic_env = ~s([{"router": 200}])
    expected = [[topic: "router", partition_count: 200]]
    assert Utils.env_to_topics_spec(topic_env) == expected
  end

  test "many entries json topics returns topic spec" do
    topic_env = ~s([{"router": 200}, {"_other": 100}])
    expected = [[topic: "router", partition_count: 200],
                [topic: "_other", partition_count: 100]]
    assert Utils.env_to_topics_spec(topic_env) == expected
  end

end
