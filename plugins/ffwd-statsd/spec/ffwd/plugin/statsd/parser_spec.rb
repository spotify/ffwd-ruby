require 'ffwd/plugin/statsd/parser'

describe FFWD::Plugin::Statsd::Parser do
  it "should parse gauge" do
    expect(described_class.parse("foo:12|g")).to eq(
      {:proc => nil, :key => "foo", :value => 12})
  end

  it "should parse count" do
    expect(described_class.parse("foo:12|c")).to eq(
      {:proc => FFWD::Plugin::Statsd::Parser::COUNT, :key => "foo",
       :value => 12})
  end

  it "should parse meter" do
    expect(described_class.parse("foo:12|m")).to eq(
      {:proc => FFWD::Plugin::Statsd::Parser::RATE, :key => "foo",
       :value => 12})
  end

  it "should parse histogram" do
    expect(described_class.parse("foo:12|ms")).to eq(
      {:proc => FFWD::Plugin::Statsd::Parser::HISTOGRAM, :key => "foo",
       :value => 12})
    expect(described_class.parse("foo:12|h")).to eq(
      {:proc => FFWD::Plugin::Statsd::Parser::HISTOGRAM, :key => "foo",
       :value => 12})
  end

  it "should reject unknown type" do
    expect{
      described_class.parse("foo:12|unknown")
    }.to raise_error(FFWD::Plugin::Statsd::ParserError)
  end
end
