require 'ffwd/plugin/statsd/connection'

describe FFWD::Plugin::Statsd::Connection::UDP do
  it "should ffwd frames to parser" do
    bind = double
    core = double(:input => double)
    c = described_class.new(nil, bind, core)
    FFWD::Plugin::Statsd::Parser.should_receive(:parse).with(:data){:metric}
    core.input.should_receive(:metric).with(:metric)
    bind.should_receive(:increment).with(:received_metrics)
    c.receive_data :data
  end
end
