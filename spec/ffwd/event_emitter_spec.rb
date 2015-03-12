require 'ffwd/event_emitter'

describe FFWD::EventEmitter do
  let(:output) {double}
  let(:host) {double}
  let(:ttl) {double}
  let(:tags) {double}
  let(:attributes) {double}

  let(:c) do
    described_class.new output, host, ttl, tags, attributes
  end

  let(:now) do
    double
  end

  let(:event) do
    double
  end

  describe "#emit" do
    def make_e opts={}
      {:time => :time, :host => :host, :ttl => :ttl, :tags => :tags,
       :attributes => :attributes, :value => :value}.merge(opts)
    end

    it "#emit should output event" do
      expect(FFWD::Event).to receive(:make){event}
      expect(output).to receive(:event).with(event)
      c.emit make_e
    end

    it "#emit should fix NaN value in events" do
      expect(FFWD::Event).to receive(:make).with(
        :tags => :tags, :attributes => :attributes,
        :fixed_tags=>tags, :fixed_attr=>attributes,
        :value => nil, :time => :time, :host => :host, :ttl => :ttl){event}
      expect(output).to receive(:event).with(event)
      c.emit make_e(:value => Float::NAN)
    end
  end
end
