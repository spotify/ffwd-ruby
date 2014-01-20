require 'evd/processor/histogram'

describe EVD::Processor::HistogramProcessor do
  EVD.log_disable

  let(:emitter) do
    double
  end

  it "should submit some of it's incoming metrics to cache" do
    histogram = described_class.new emitter, {}

    cache = histogram.instance_variable_get "@cache"
    histogram.instance_variable_set "@timer", :timer

    histogram.process :key => :foo, :value => :bar
    histogram.process :key => :foo, :value => :baz
    cache.should eq({:foo => [:bar, :baz]})
  end

  it "drop metrics if bucket size reached" do
    histogram = described_class.new emitter, {:bucket_limit => 1}

    cache = histogram.instance_variable_get "@cache"
    histogram.instance_variable_set "@timer", :timer

    histogram.process :key => :foo, :value => :bar
    histogram.process :key => :foo, :value => :baz
    cache.should eq({:foo => [:bar]})
  end

  it "drop metrics if cache size reached" do
    histogram = described_class.new emitter, {:cache_limit => 1}

    cache = histogram.instance_variable_get "@cache"
    histogram.instance_variable_set "@timer", :timer

    histogram.process :key => :foo1, :value => :bar
    histogram.process :key => :foo2, :value => :baz
    cache.should eq({:foo1 => [:bar]})
  end
end
