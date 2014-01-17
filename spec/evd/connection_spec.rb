require 'evd/connection'
require 'eventmachine'

describe EVD::Connection do
  it "should dispatch all send_data to eventmachine" do
    EM.should_receive(:send_data).with(:sub, "data", 4)
    c = EVD::Connection.new :sub
    c.send_data :data
  end

  it "should dispatch all send_data to datasink" do
    EM.should_not_receive(:send_data)
    datasink = double
    datasink.should_receive(:<<).with(:data)
    c = EVD::Connection.new :sub
    c.datasink= datasink
    c.send_data :data
  end
end

