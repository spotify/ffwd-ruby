require 'evd/plugin/statsd'

describe EVD::Plugin::Statsd::Parser do
  it "should parse count" do
    described_class.parse("foo:12|g").should eq(
      {:proc => nil, :key => "foo",
       :value => 12})
    described_class.parse("foo:12|c").should eq(
      {:proc => EVD::Plugin::Statsd::Parser::COUNT, :key => "foo",
       :value => 12})
    described_class.parse("foo:12|ms").should eq(
      {:proc => EVD::Plugin::Statsd::Parser::HISTOGRAM, :key => "foo",
       :value => 12})
  end
end

describe EVD::Plugin::Statsd::Connection do
  it "should forward frames to parser" do
    input, output = double, double
    c = described_class.new(nil, input, output)
    EVD::Plugin::Statsd::Parser.should_receive(:parse).with(:data){:metric}
    input.should_receive(:metric).with(:metric)
    c.receive_data :data
  end
end
