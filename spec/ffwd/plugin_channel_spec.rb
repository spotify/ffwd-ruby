require 'ffwd/plugin_channel'

describe FFWD::PluginChannel do
  let(:name) {double}
  let(:events) {double}
  let(:metrics) {double}

  let(:c) do
    FFWD::PluginChannel.new name, events, metrics
  end

  it "should forward attributes" do
    c.events.should equal(events)
    c.metrics.should equal(metrics)
  end

  it "#event_subscribe should forward" do
    events.should_receive(:subscribe).and_yield(:foo, :bar)
    c.event_subscribe do |first, second|
      first.should eq(:foo)
      second.should eq(:bar)
    end
  end

  it "#event should forward to #events" do
    events.should_receive(:<<).with(:foo)
    c.event :foo
    c.reporter_data.should eq(:total=>1, :metrics=>0, :events=>1)
  end

  it "#metric_subscribe should forward" do
    metrics.should_receive(:subscribe).and_yield(:foo, :bar)
    c.metric_subscribe do |first, second|
      first.should eq(:foo)
      second.should eq(:bar)
    end
  end

  it "#metric should forward to #events" do
    metrics.should_receive(:<<).with(:foo)
    c.metric :foo
    c.reporter_data.should eq(:total=>1, :metrics=>1, :events=>0)
  end

  it "#reporter_meta should contain correct metadata" do
    c.reporter_meta.should eq(:plugin_channel => name, :type => "plugin_channel")
  end
end
