require 'ffwd/plugin/riemann'

require 'ffwd/test/protocol'

FFWD::Plugin::Riemann::OUTPUTS.each do |proto, output_class|
  describe output_class do
    include FFWD::Test::Protocol

    it "#{proto}: should use the protocol infrastructure" do
      valid_output described_class
    end
  end
end
