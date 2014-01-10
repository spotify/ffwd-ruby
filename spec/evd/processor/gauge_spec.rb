require 'evd/processor/gauge'

describe EVD::Processor::GaugeProcessor do
  EVD.log_disable

  opts = {}
  m1 = {:key => :foo, :value => 10}
  m2 = {:key => :foo}

  let(:gauge) do
    EVD::Processor::GaugeProcessor.new opts
  end

  it "should preserve the original message" do
    core = double
    core.should_receive(:emit).with m1.merge(:source => m1[:key])
    gauge.process core, m1
  end

  it "should make sure that there is a default value" do
    core = double
    core.should_receive(:emit).with m2.merge(
      :value => EVD::Processor::GaugeProcessor::DEFAULT_MISSING,
      :source => m2[:key])
    gauge.process core, m2
  end
end
