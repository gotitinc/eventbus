defmodule Eventbus.ConfigStoreTest do
  use ExUnit.Case
  alias Eventbus.{ConfigStore, Utils}

  setup do
    ConfigStore.init()
    {:ok, %{}}
  end

  test "unconfigured config store" do
    assert is_nil(ConfigStore.get_topics_spec())
    assert is_nil(ConfigStore.get_topic_spec("default"))
    assert is_nil(ConfigStore.get_topic_count("default"))
  end

  test "default configuration" do
    Application.get_env(:eventbus, :topics, [])
    |> ConfigStore.put_topics_spec()

    assert ConfigStore.get_topics_spec() ==
      [[topic: "router", partition_count: 1],
       [topic: "default", partition_count: 2],
       [topic: "pusher", partition_count: 3],
       [topic: "analytics", partition_count: 4],
       [topic: "_other", partition_count: 1]]
    assert ConfigStore.get_topic_spec("default") == [topic: "default", partition_count: 2]
    assert ConfigStore.get_topic_count("default") == 2
  end

  test "custom json configuration" do
    ~s([{"router": 200}, {"_other": 100}])
    |> Utils.env_to_topics_spec()
    |> ConfigStore.put_topics_spec()

    assert ConfigStore.get_topics_spec() ==
      [[topic: "router", partition_count: 200],
       [topic: "_other", partition_count: 100]]
    assert ConfigStore.get_topic_spec("router") == [topic: "router", partition_count: 200]
    assert ConfigStore.get_topic_count("router") == 200
  end

  test "no _other topic" do
    assert ConfigStore.validate_topic("router") == {:error, "invalid topic"}
  end

  test "valid existing topic" do
    Application.get_env(:eventbus, :topics, [])
    |> ConfigStore.put_topics_spec()

    assert ConfigStore.validate_topic("router") == {:ok, "router"}
  end

  test "default to _other topic" do
    Application.get_env(:eventbus, :topics, [])
    |> ConfigStore.put_topics_spec()

    assert ConfigStore.validate_topic("foo") == {:ok, "_other"}
  end

end
