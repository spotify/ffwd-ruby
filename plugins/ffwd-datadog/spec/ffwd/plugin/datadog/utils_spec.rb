require 'ffwd/plugin/datadog/utils'

describe FFWD::Plugin::Datadog::Utils do
  describe "#safe_string" do
    it "should escape unsafe characters" do
      described_class.safe_string("foo bar").should eq("foo_bar")
      described_class.safe_string("foo:bar").should eq("foo_bar")
    end
  end

  describe "#make_tags" do
    it "should build safe tags" do
      tags = {:foo => "bar baz"}
      ref = ["foo:bar_baz"]
      described_class.safe_tags(tags).should eq(ref)
    end
  end

  describe "#safe_entry" do
    it "should escape parts of entries" do
      entry = {:name => :name, :host => :host, :attributes => {:foo => "bar baz"}}
      ref = {:metric=>"name", :host => :host, :tags=>["foo:bar_baz"]}
      described_class.safe_entry(entry).should eq(ref)
    end
  end
end
