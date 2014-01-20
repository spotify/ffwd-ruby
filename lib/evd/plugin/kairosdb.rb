require 'eventmachine'
require 'em-http'

require_relative '../protocol'
require_relative '../plugin'
require_relative '../logging'
require_relative '../connection'

module EVD::Plugin::KairosDB
  include EVD::Plugin
  include EVD::Logging

  register_plugin "kairosdb"

  class OutputKDB
    HEADER = {
      "Content-Type" => "application/json"
    }

    def initialize log, opts={}
      @log = log
      @url = opts[:url]
      @api_url = "#{@url}/api/v1/datapoints"
      @flush_interval = opts[:flush_interval]
      @buffer_limit = opts[:buffer_limit]
      @buffer = []
      @dropped_metrics = 0
      @sub = nil
      @http = nil
    end

    def flush!
      if @timer
        @timer.cancel
        @timer = nil
      end

      if @http
        @log.info "Request already in progress, dropping metrics"
        @dropped_metrics += @buffer.size
        @buffer = []
        return
      end

      events = make_events(@buffer)
      @buffer = []
      count = events.size

      events = JSON.dump(events)

      @http = EventMachine::HttpRequest.new(@api_url).post(
        :body => events, :head => HEADER)

      @http.callback do
        @log.debug "#{count} event(s) successfully submitted"
        @http = nil
      end

      @http.errback do
        @log.error "Failed to submit events"
        @dropped_metrics += count
        @http = nil
      end
    end

    # optimized, makes the assumption that all events have the same metadata as
    # the first seen one.
    def make_events buffer
      groups = {}

      buffer.each do |metric|
        group = (groups[metric.key] ||= {
          :name => metric.key, :tags => make_tags(metric),:datapoints => []})
        group[:datapoints] << [(metric.time.to_f * 1000).to_i, metric.value]
      end

      return groups.values
    end

    def make_tags metric
      tags = {
        "host" => metric.host
      }

      metric.attributes.each do |key, value|
        tags[key] = value
      end

      metric.tags.each do |tag|
        tags[tag] = ""
      end

      return tags
    end

    def check_timer!
      return if @timer

      @log.debug "Setting timer to #{@flush_interval}s"

      @timer = EM::Timer.new(@flush_interval) do
        flush!
      end
    end

    def start output
      @log.info "Sending to #{@url}"

      @sub = output.metric_subscribe do |metric|
        if @buffer.size >= @buffer_limit
          @dropped_metrics += 1
        end

        @buffer << metric
        check_timer!
      end
    end

    def stop
      if @timer
        @timer.cancel
        @timer = nil
      end

      if @sub
        @sub.stop
        @sub = nil
      end
    end
  end

  DEFAULT_URL = "http://localhost:8080"
  DEFAULT_FLUSH_INTERVAL = 10
  DEFAULT_BUFFER_LIMIT = 100000

  def self.setup_output core, opts={}
    opts[:url] ||= DEFAULT_URL
    opts[:flush_interval] ||= DEFAULT_FLUSH_INTERVAL
    opts[:buffer_limit] ||= DEFAULT_BUFFER_LIMIT
    OutputKDB.new log, opts
  end
end
