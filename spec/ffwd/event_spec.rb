require 'ffwd/event'

describe FFWD::Event do
  it "should be possible to access key" do
    described_class.make(:key => :key).key.should eq(:key)
  end

  it "should be sparsely serializable through to_h" do
    described_class.make(:key => :key).to_h.should eq({:key => :key})
  end
end
