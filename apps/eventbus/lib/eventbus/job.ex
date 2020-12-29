defprotocol Eventbus.Job do
  @doc "Encapsulates a computation that need to be executed"
  def call(job)
end
