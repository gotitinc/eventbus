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
end
