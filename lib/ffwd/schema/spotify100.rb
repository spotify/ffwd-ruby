require_relative '../schema'

require 'json'

module FFWD::Schema
  # Spotify's metric schema.
  module Spotify100
    include FFWD::Schema

    VERSION = "1.0.0"

    module ApplicationJSON
      def self.dump_metric m
        d = {}
        d[:version] = VERSION
        d[:time] = (m.time.to_f * 1000).to_i if m.time
        d[:key] = m.key if m.key
        d[:value] = m.value if m.value
        d[:host] = m.host if m.host
        d[:tags] = m.tags.to_a if m.tags
        d[:attributes] = m.attributes if m.attributes
        JSON.dump d
      end

      def self.dump_event e
        d = {}
        d[:version] = VERSION
        d[:time] = (e.time.to_f * 1000).to_i if e.time
        d[:key] = e.key if e.key
        d[:value] = e.value if e.value
        d[:host] = e.host if e.host
        d[:state] = e.state if e.state
        d[:description] = e.description if e.description
        d[:ttl] = e.ttl if e.ttl
        d[:tags] = e.tags.to_a if e.tags
        d[:attributes] = e.attributes if e.attributes
        JSON.dump d
      end
    end

    register_schema 'spotify 1.0.0', 'application/json', ApplicationJSON
  end
end
