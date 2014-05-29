require 'ffwd/plugin/statsd/parser'

describe FFWD::Plugin::Statsd::Parser do
  it "should parse gauge" do
    described_class.parse("foo:12|g").should eq(
      {:proc => nil, :key => "foo", :value => 12})
  end

  it "should parse count" do
    described_class.parse("foo:12|c").should eq(
      {:proc => FFWD::Plugin::Statsd::Parser::COUNT, :key => "foo",
       :value => 12})
  end

  it "should parse meter" do
    described_class.parse("foo:12|m").should eq(
      {:proc => FFWD::Plugin::Statsd::Parser::RATE, :key => "foo",
       :value => 12})
  end

  it "should parse histogram" do
    described_class.parse("foo:12|ms").should eq(
      {:proc => FFWD::Plugin::Statsd::Parser::HISTOGRAM, :key => "foo",
       :value => 12})
    described_class.parse("foo:12|h").should eq(
      {:proc => FFWD::Plugin::Statsd::Parser::HISTOGRAM, :key => "foo",
       :value => 12})
  end

  it "should reject unknown type" do
    expect{
      described_class.parse("foo:12|unknown")
    }.to raise_error(FFWD::Plugin::Statsd::ParserError)
  end
end
