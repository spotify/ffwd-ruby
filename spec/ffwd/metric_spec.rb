require 'ffwd/metric'

describe FFWD::Metric do
  it "should be able to access key" do
    described_class.make(:key => :key).key.should eq(:key)
  end

  it "should be sparsely serializable through to_h" do
    described_class.make(:key => :key).to_h.should eq({:key => :key})
  end
end
