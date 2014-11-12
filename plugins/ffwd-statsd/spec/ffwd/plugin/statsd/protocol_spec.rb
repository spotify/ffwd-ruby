require 'ffwd/plugin/statsd'

require 'ffwd/test/protocol'

describe FFWD::Plugin::Statsd::InputTCP do
  include FFWD::Test::Protocol

  it "should use the protocol infrastructure" do
    valid_input described_class, :config => {:key => "statsd"}
  end
end

describe FFWD::Plugin::Statsd::InputUDP do
  include FFWD::Test::Protocol

  it "should use the protocol infrastructure" do
    valid_input described_class, :config => {:key => "statsd"}
  end
end
