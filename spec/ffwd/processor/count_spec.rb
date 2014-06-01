require 'ffwd/processor/count'

describe FFWD::Processor::CountProcessor do
  FFWD.log_disable

  opts = {}
  m1 = {:key => "foo", :value => 10}

  let(:metric) do
    double
  end

  let(:emitter) do
    double :metric => metric
  end

  let(:count) do
    described_class.new emitter, described_class.prepare(opts)
  end

  it "should realize that 10 + 10 = 20" do
    Time.stub(:now).and_return(0)

    metric.should_receive(:emit).with m1.merge(
      :key => m1[:key], :value => m1[:value] * 2, :source => m1[:key],
      :attributes => nil, :tags => nil)

    count.should_receive(:check_timer)
    count.should_receive(:check_timer)

    count.process m1
    count.process m1
    count.digest! 0
  end
end
