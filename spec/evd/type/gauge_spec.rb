require 'evd/type/gauge'

describe EVD::Type::Gauge do
  EVD.log_disable

  opts = {}
  m1 = {:key => :foo, :value => 10}
  m2 = {:key => :foo}

  let(:gauge) do
    EVD::Type::Gauge.new opts
  end

  it "should preserve the original message" do
    core = double
    gauge.core = core
    core.should_receive(:emit).with m1.merge(
      :source => m1[:key])
    gauge.process m1
  end

  it "should make sure that there is a default value" do
    core = double
    gauge.core = core
    core.should_receive(:emit).with m2.merge(
      :value => EVD::Type::Gauge::DEFAULT_MISSING,
      :source => m2[:key])
    gauge.process m2
  end
end
