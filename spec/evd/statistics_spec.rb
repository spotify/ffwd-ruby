require 'evd/statistics'

describe EVD::Statistics::Collector do
  EVD.log_disable

  let(:out) { {:key => EVD::Statistics::OUT_RATE,
               :source => EVD::Statistics::OUT,
               :tags => EVD::Statistics::INTERNAL_TAGS} }

  let(:inp) { {:key => EVD::Statistics::IN_RATE,
               :source => EVD::Statistics::IN,
               :tags => EVD::Statistics::INTERNAL_TAGS} }

  let(:core) { double }
  let(:period) { 10 }
  let(:precision) { 3 }

  let(:s) do
    EVD::Statistics::Collector.new core, period, precision
  end

  it "should count input and output" do
    s.input_inc
    s.output_inc

    core.should_receive(:emit).with inp.merge(:value => 1)
    core.should_receive(:emit).with out.merge(:value => 1)

    s.generate! 0, 1
  end
end
