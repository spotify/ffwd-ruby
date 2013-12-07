require 'evd/type/count'

describe EVD::Type::Count do
  EVD.log_disable

  opts = {}
  m1 = {:key => :foo, :value => 10}
  m2 = {:key => :foo, :value => 10, :attributes => {:bar => :baz}}

  let(:count) do
    EVD::Type::Count.new opts
  end

  it "should realize that 10 + 10 = 20" do
    core = double
    count.core = core
    core.should_receive(:emit).with m1.merge(
      :source => m1[:key])
    count.process m1
    core.should_receive(:emit).with m1.merge(
      :value => m1[:value] * 2, :source => m1[:key])
    count.process m1
  end

  it "should preserve extra parameters" do
    core = double
    count.core = core
    core.should_receive(:emit).with m2.merge(
      :source => m2[:key])
    count.process m2
    core.should_receive(:emit).with m2.merge(
      :value => m2[:value] * 2, :source => m2[:key])
    count.process m2
  end
end
