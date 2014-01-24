require 'ffwd/core_emitter'

describe FFWD::CoreEmitter do
  it "should ffwd events and metrics" do
    output = double
    event_emitter = double
    metric_emitter = double
    event_emitter.should_receive(:emit).with(:event)
    metric_emitter.should_receive(:emit).with(:metric)
    FFWD::EventEmitter.should_receive(:new){event_emitter}
    FFWD::MetricEmitter.should_receive(:new){metric_emitter}
    emitter = described_class.new output
    emitter.emit_event :event
    emitter.emit_metric :metric
  end
end

