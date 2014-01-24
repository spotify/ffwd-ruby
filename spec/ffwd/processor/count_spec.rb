require 'ffwd/processor/count'

describe FFWD::Processor::CountProcessor do
  FFWD.log_disable

  opts = {}
  m1 = {:key => :foo, :value => 10}

  let(:emitter) do
    double
  end

  let(:count) do
    described_class.new emitter, opts
  end

  it "should realize that 10 + 10 = 20" do
    emitter.should_receive(:emit_metric).with m1.merge(
      :source => m1[:key])
    count.process m1

    emitter.should_receive(:emit_metric).with m1.merge(
      :value => m1[:value] * 2, :source => m1[:key])
    count.process m1
  end
end
