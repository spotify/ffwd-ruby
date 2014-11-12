require 'ffwd/core/processor'

describe FFWD::Core::Processor do
  it "should setup lifecycle listeners" do
    input = double
    emitter = double
    p1 = double
    processors = {:foo => p1}
    reporters = []
    expect(input).to receive(:starting)
    expect(input).to receive(:stopping)
    expect(p1).to receive(:depend_on).with(input)
    described_class.new input, emitter, processors, reporters
  end
end
