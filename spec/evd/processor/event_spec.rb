require 'evd/processor/event'

describe EVD::Processor::EventProcessor do
  EVD.log_disable

  opts = {}
  m1 = {:key => :foo, :ttl => 10}
  m2 = {:key => :foo}

  let(:event) do
    EVD::Processor::EventProcessor.new opts
  end

  it "should set default ttl on message if missing" do
    core = double
    event.core = core
    core.should_receive(:emit).with m1.merge(
      :source => :foo)
    event.process m1
    core.should_receive(:emit).with m2.merge(
      :ttl => EVD::Processor::EventProcessor::DEFAULT_TTL,
      :source => :foo)
    event.process m2
  end
end
