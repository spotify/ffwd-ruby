require 'ffwd/plugin/collectd'
require 'ffwd/plugin/collectd/types_db'

require 'ffwd/test/protocol'

FFWD::Plugin::Collectd::INPUTS.each do |proto, input_class|
  describe input_class do
    include FFWD::Test::Protocol

    it "#{proto}: should use the protocol infrastructure" do
      config = {:types_db => :path}
      FFWD::Plugin::Collectd::TypesDB.should_receive(:open).with(:path)
      valid_input described_class, :config => config
    end
  end
end
