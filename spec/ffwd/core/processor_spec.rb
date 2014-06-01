require 'ffwd/core/processor'

describe FFWD::Core::Processor do
  it "should setup lifecycle listeners" do
    input = double
    emitter = double
    p1 = double
    processors = {:foo => p1}
    reporters = []
    input.should_receive :starting
    input.should_receive :stopping
    p1.should_receive(:depend_on).with(input)
    described_class.new input, emitter, processors, reporters
  end
end
