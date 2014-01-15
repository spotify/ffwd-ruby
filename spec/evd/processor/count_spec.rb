require 'evd/processor/count'

describe EVD::Processor::CountProcessor do
  EVD.log_disable

  opts = {}
  m1 = {:key => :foo, :value => 10}

  let(:count) do
    EVD::Processor::CountProcessor.new opts
  end

  it "should realize that 10 + 10 = 20" do
    core = double
    core.should_receive(:emit_metric).with m1.merge(
      :source => m1[:key])
    count.process core, m1

    core.should_receive(:emit_metric).with m1.merge(
      :value => m1[:value] * 2, :source => m1[:key])
    count.process core, m1
  end
end
