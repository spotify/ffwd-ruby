require 'evd/update_hash'

describe EVD::UpdateHash do
  let(:base_array){[:bar]}
  let(:base_hash){{:bar => :bar_val}}
  let(:limit){1}
  let(:oper_array){lambda{|a, b| a.+ b}}
  let(:oper_hash){lambda{|a, b| a.merge b}}
  let(:target){Hash.new}

  let(:update_array){
    EVD::UpdateHash.new(base_array, target, limit, oper_array)
  }

  let(:update_hash){
    EVD::UpdateHash.new(base_hash, target, limit, oper_hash)
  }

  it "should process array" do
    update_array.process(:key => :key, :value => [:baz])
    target.should eq({:key => [:bar, :baz]})
  end

  it "should process hash" do
    update_hash.process(:key => :key, :value => {:foo => :foo_val})
    target.should eq({:key => {:bar => :bar_val, :foo => :foo_val}})
  end

  it "should limit updates" do
    update_hash.process(:key => :key1, :value => {:foo => :foo_val})
    update_hash.process(:key => :key2, :value => {:foo => :foo_val})
    target.should eq({:key1 => {:bar => :bar_val, :foo => :foo_val}})
  end

  it "should delete keys" do
    update_hash.process(:key => :bar, :value => nil)
    target.should eq({})
  end
end
