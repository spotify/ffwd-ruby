require 'ffwd/plugin/carbon'

require 'ffwd/test/protocol'

FFWD::Plugin::Carbon::INPUTS.each do |proto, input_class|
  describe input_class do
    include FFWD::Test::Protocol

    it "#{proto}: should use the protocol infrastructure" do
      valid_input described_class
    end
  end
end
