require 'ffwd/plugin/protobuf'

require 'ffwd/test/protocol'

FFWD::Plugin::Protobuf::INPUTS.each do |proto, input_class|
  describe input_class do
    include FFWD::Test::Protocol

    it "#{proto}: should use the protocol infrastructure" do
      valid_input described_class
    end
  end
end

FFWD::Plugin::Protobuf::OUTPUTS.each do |proto, output_class|
  describe output_class do
    include FFWD::Test::Protocol

    it "#{proto}: should use the protocol infrastructure" do
      valid_output described_class
    end
  end
end
