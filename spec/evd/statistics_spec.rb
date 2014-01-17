require 'evd/statistics'

describe EVD::Statistics::Collector do
  EVD.log_disable

  let(:emitter) {double}
  let(:c1) {double}
  let(:c2) {double}

  let(:opts) {{:period => 10, :precision => 3, :tags => ['internal'],
               :attributes => {:foo => :bar}}}

  let(:s) do
    EVD::Statistics::Collector.new emitter, [c1, c2], opts
  end

  it "should collect and emit statistics from all channels provided" do
    c1.should_receive(:stats!) { {:foo => 20} }
    c2.should_receive(:stats!) { {:bar => 30} }
    c1.should_receive(:kind) {:kind1}
    c2.should_receive(:kind) {:kind2}

    emitter.should_receive(:emit_metric).with({
      :key=>"kind1.foo.rate", :source=>"kind1.foo", :value=>2.0,
      :tags => Set.new(['internal']), :attributes => {:foo => :bar}})

    emitter.should_receive(:emit_metric).with({
      :key=>"kind2.bar.rate", :source=>"kind2.bar", :value=>3.0,
      :tags => Set.new(['internal']), :attributes => {:foo => :bar}})

    last = 0
    now = 10

    s.generate! last, now
  end
end
