require 'ffwd/handler'

describe FFWD::Handler do
  let(:sig){double}
  let(:parent){double}

  it "#unbind should forward to parent" do
    parent.should_receive(:unbind)
    instance = described_class.new sig, parent
    instance.unbind
  end

  it "#connection_completerd should forward to parent" do
    parent.should_receive(:connection_completed)
    instance = described_class.new sig, parent
    instance.connection_completed
  end
end
