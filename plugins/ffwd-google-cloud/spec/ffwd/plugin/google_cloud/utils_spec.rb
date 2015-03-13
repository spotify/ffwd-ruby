require 'ffwd/plugin/google_cloud/utils'

describe FFWD::Plugin::GoogleCloud::Utils do
  it "should hash attributes the same" do
    a = described_class.hash_labels(:foo => 1, :bar => 2, :baz => 3)
    b = described_class.hash_labels(:bar => 1, :baz => 2, :foo => 3)
    c = described_class.hash_labels(:bar => 1, :baz => 2, :foo => 3, :biz => 4)
    expect(a).to eq(b)
    expect(a).not_to eq(c)
  end

  it "should hash attributes of a large object consistently" do
    large = {}

    (0..10000).each do |v|
      large[v.to_s] = v
    end

    expect(described_class.hash_labels(large).to_s(32)).to eq("fi131fce6kalu")
  end
end
