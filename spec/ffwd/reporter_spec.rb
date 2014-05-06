require 'ffwd/reporter'

describe FFWD::Reporter do
  let(:i1) do
    o = Class.new
    o.send(:include, described_class)
    o.setup_reporter :keys => [:foo]
    o.new
  end

  it "#increment should update counters" do
    i1.increment :foo
  end

  it "#increment should throw exception on missing key" do
    expect{i1.increment :bar}.to raise_error(FFWD::Reporter::MissingReporterKey)
  end
end
