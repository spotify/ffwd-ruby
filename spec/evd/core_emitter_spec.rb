require 'evd/core_emitter'

describe EVD::CoreEmitter do
  it "should forward events and metrics" do
    output = double
    event_emitter = double
    metric_emitter = double
    event_emitter.should_receive(:emit).with(:event)
    metric_emitter.should_receive(:emit).with(:metric)
    EVD::EventEmitter.should_receive(:new){event_emitter}
    EVD::MetricEmitter.should_receive(:new){metric_emitter}
    emitter = described_class.new output
    emitter.emit_event :event
    emitter.emit_metric :metric
  end
end

