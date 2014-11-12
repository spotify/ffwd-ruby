require 'ffwd/plugin/kairosdb/utils'

describe FFWD::Plugin::KairosDB::Utils do
  describe "#safe_string" do
    it "should escape unsafe characters" do
      expect(described_class.safe_string("foo bar")).to eq("foo/bar")
      expect(described_class.safe_string("foo:bar")).to eq("foo_bar")
    end
  end

  describe "#make_tags" do
    it "should build safe tags" do
      tags = {:foo => "bar/baz"}
      ref = {"host"=>"host", "foo"=>"bar/baz"}
      expect(described_class.safe_tags(:host, tags)).to eq(ref)
    end
  end

  describe "#safe_entry" do
    it "should escape parts of entries" do
      entry = {:name => :name, :host => :host, :attributes => {:foo => "bar/baz"}}
      ref = {:name=>"name", :tags=>{"host"=>"host", "foo"=>"bar/baz"}}
      expect(described_class.safe_entry(entry)).to eq(ref)
    end
  end
end
