require 'ffwd/plugin/json'

require 'ffwd/test/protocol'

describe FFWD::Plugin::JSON::LineConnection do
  include FFWD::Test::Protocol

  it "should use the protocol infrastructure" do
    valid_input described_class
  end
end

describe FFWD::Plugin::JSON::FrameConnection do
  include FFWD::Test::Protocol

  it "should use the protocol infrastructure" do
    valid_input described_class
  end
end
