require_relative '../schema'

require 'json'

module FFWD::Schema
  module Default
    include FFWD::Schema

    module ApplicationJSON
      def self.dump_metric m
        JSON.dump m.to_h
      end

      def self.dump_event e
        JSON.dump e.to_h
      end
    end

    register_schema 'default', 'application/json', ApplicationJSON
  end
end
