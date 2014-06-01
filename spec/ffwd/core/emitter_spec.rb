require 'ffwd/core/emitter'

describe FFWD::Core::Emitter do
  it "should make event and metric emitters accessible" do
    event = double
    metric = double
    i = described_class.new event, metric
    i.event.should eq(event)
    i.metric.should eq(metric)
  end
end
