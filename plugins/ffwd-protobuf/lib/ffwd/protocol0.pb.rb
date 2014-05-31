## Generated from proto/protocol0.proto for ffwd.protocol0
require "beefcake"

module FFWD
  module Protocol0

    class Metric
      include Beefcake::Message
    end

    class Event
      include Beefcake::Message
    end

    class Attribute
      include Beefcake::Message
    end

    class Message
      include Beefcake::Message
    end

    class Metric
      optional :proc, :string, 1
      optional :time, :int64, 2
      optional :key, :string, 3
      optional :value, :double, 4
      optional :host, :string, 5
      repeated :tags, :string, 6
      repeated :attributes, Attribute, 7
    end

    class Event
      optional :time, :int64, 1
      optional :key, :string, 2
      optional :value, :double, 3
      optional :host, :string, 4
      optional :state, :string, 5
      optional :description, :string, 6
      optional :ttl, :int64, 7
      repeated :tags, :string, 8
      repeated :attributes, Attribute, 9
    end

    class Attribute
      required :key, :string, 1
      optional :value, :string, 2
    end

    class Message
      optional :metric, Metric, 1
      optional :event, Event, 2
    end
  end
end
