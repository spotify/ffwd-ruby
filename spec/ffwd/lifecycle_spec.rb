require 'ffwd/lifecycle'

describe FFWD::Lifecycle do
  it "should allow class to get a stopping callback" do
    class Foo
      include FFWD::Lifecycle
    end

    block = double
    block.should_receive(:call)

    f = Foo.new

    f.stopping do |*args|
      block.call(*args)
    end

    f.stopped?.should eq(false)
    f.stop
    f.stopped?.should eq(true)
  end
end
