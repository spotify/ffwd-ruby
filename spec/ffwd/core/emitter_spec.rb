require 'ffwd/core/emitter'

describe FFWD::Core::Emitter do
  it "should make event and metric emitters accessible" do
    event = double
    metric = double
    i = described_class.new event, metric
    expect(i.event).to eq(event)
    expect(i.metric).to eq(metric)
  end
end
