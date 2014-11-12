require 'ffwd/lifecycle'

describe FFWD::Lifecycle do
  it "should allow class to get a stopping callback" do
    class Foo
      include FFWD::Lifecycle
    end

    block = double
    expect(block).to receive(:call)

    f = Foo.new

    f.stopping do |*args|
      block.call(*args)
    end

    expect(f.stopped?).to eq(false)
    f.stop
    expect(f.stopped?).to eq(true)
  end
end
