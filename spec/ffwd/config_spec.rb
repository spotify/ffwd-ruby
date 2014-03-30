require 'ffwd/config'

describe FFWD::Config do
  it "should parse a single field correctly" do
    class A
      include FFWD::Config::Section

      section_field "field", :type => :int
    end

    a = A.parse({"field" => 12})
    a.field.should eq(12)
  end

  it "should parse a subfield type correctly" do
    class B
      include FFWD::Config::Section
      section_field "field", :type => :int, :default => 42
      section_array "list", :type => :int, :default => []
    end

    class A
      include FFWD::Config::Section
      section_field "field", :type => B
    end

    a = A.parse({"field" => {"field" => 12}})
    a.field.should be_a(B)
    a.field.field.should eq(12)
    a.field.list.should eq([])

    a = A.parse({"field" => {"list" => [1,2,3]}})
    a.field.should be_a(B)
    a.field.field.should eq(42)
    a.field.list.should eq([1,2,3])
  end

  it "should have working notifiers" do
    class A
      include FFWD::Config::Section
      section_field "field", :type => :int, :default => 42
    end

    v = double
    v.should_receive(:notify)

    a = A.parse

    a.notify do
      v.notify
    end

    a.notify!
  end
end
