require 'ffwd/plugin_channel'

describe FFWD::PluginChannel do
  let(:name) {double}
  let(:events) {double}
  let(:metrics) {double}

  let(:c) do
    FFWD::PluginChannel.new name, events, metrics
  end

  it "should forward attributes" do
    expect(c.events).to equal(events)
    expect(c.metrics).to equal(metrics)
  end

  it "#event_subscribe should forward" do
    expect(events).to receive(:subscribe).and_yield(:foo, :bar)
    c.event_subscribe do |first, second|
      expect(first).to eq(:foo)
      expect(second).to eq(:bar)
    end
  end

  it "#event should forward to #events" do
    expect(events).to receive(:<<).with(:foo)
    c.event :foo
    expect(c.reporter_data).to eq(:metrics=>0, :events=>1)
  end

  it "#metric_subscribe should forward" do
    expect(metrics).to receive(:subscribe).and_yield(:foo, :bar)
    c.metric_subscribe do |first, second|
      expect(first).to eq(:foo)
      expect(second).to eq(:bar)
    end
  end

  it "#metric should forward to #events" do
    expect(metrics).to receive(:<<).with(:foo)
    c.metric :foo
    expect(c.reporter_data).to eq(:metrics=>1, :events=>0)
  end

  it "#reporter_meta should contain correct metadata" do
    expect(c.reporter_meta).to eq(:plugin_channel => name, :type => "plugin_channel")
  end
end
