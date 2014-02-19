require 'ffwd/connection'

describe FFWD::Connection do
  it "should dispatch all send_data to eventmachine" do
    EM.should_receive(:send_data).with(:sub, "data", 4)
    c = FFWD::Connection.new :sub
    c.send_data :data
  end

  it "should dispatch all send_data to datasink" do
    EM.should_not_receive(:send_data)
    datasink = double
    datasink.should_receive(:send_data).with(:data)
    c = FFWD::Connection.new :sub
    c.datasink= datasink
    c.send_data :data
  end
end

