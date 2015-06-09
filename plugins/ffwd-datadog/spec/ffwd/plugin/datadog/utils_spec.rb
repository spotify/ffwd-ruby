require 'ffwd/plugin/datadog/utils'

describe FFWD::Plugin::Datadog::Utils do
  describe "#safe_string" do
    it "should escape unsafe characters" do
      expect(described_class.safe_string("foo bar")).to eq("foo_bar")
      expect(described_class.safe_string("foo:bar")).to eq("foo_bar")
    end
  end

  describe "#make_tags" do
    it "should build safe tags" do
      tags = {:foo => "bar baz"}
      ref = ["foo:bar_baz"]
      expect(described_class.safe_tags(tags)).to eq(ref)
    end
  end

  describe "#safe_entry" do
    it "should escape parts of entries" do
      entry = {:name => :name, :host => :host, :attributes => {:foo => "bar baz"}}
      ref = {:metric=>"name", :host => :host, :tags=>["foo:bar_baz"]}
      expect(described_class.safe_entry(entry)).to eq(ref)
    end

    it "should use 'what' attribute as the datadog metric name" do
      entry = {:name => :name, :host => :host, :attributes => {:foo => "bar baz"}, :what => "thing"}
      ref = {:metric=>"thing", :host => :host, :tags=>["foo:bar_baz", "ffwd_key:#{:name}"]}
      expect(described_class.safe_entry(entry)).to eq(ref)
    end
  end
end
