require 'ffwd/channel'

describe FFWD::Channel do
  let(:log) {double}
  let(:name) {:foo}

  let(:c) do
    FFWD::Channel.new log, name
  end

  it "should synchronously ffwd all objects" do
    r1 = double
    r2 = double

    c.subscribe do |data|
      r1.receive data
    end

    c.subscribe do |data|
      r2.receive data
    end

    data = Object.new

    r1.should_receive(:receive).with(data)
    r2.should_receive(:receive).with(data)

    c << data
  end

  it "should log errors with provided name" do
    r1 = double

    r1.should_receive(:receive).and_raise("exception")

    c.subscribe do |data|
      r1.receive data
    end

    data = Object.new

    log.should_receive(:error).with("#{name}: Subscription failed", an_instance_of(RuntimeError))

    c << data
  end
end
