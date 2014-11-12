require 'ffwd/metric'

describe FFWD::Metric do
  it "should be able to access key" do
    expect(described_class.make(:key => :key).key).to eq(:key)
  end

  it "should be sparsely serializable through to_h" do
    expect(described_class.make(:key => :key).to_h).to eq(:key => :key)
  end
end
