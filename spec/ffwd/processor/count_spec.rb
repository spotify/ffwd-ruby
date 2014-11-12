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
    allow(Time).to receive(:now){0}

    expect(metric).to receive(:emit).with m1.merge(
      :key => m1[:key], :value => m1[:value] * 2, :source => m1[:key],
      :attributes => nil, :tags => nil)

    expect(count).to receive(:check_timer)
    expect(count).to receive(:check_timer)

    count.process m1
    count.process m1
    count.digest! 0
  end
end
