require 'eventmachine'
require 'em-http'

require 'ffwd/logging'
require 'ffwd/plugin'
require 'ffwd/reporter'

module FFWD::Plugin::KairosDB
  include FFWD::Plugin
  include FFWD::Logging

  register_plugin "kairosdb"

  class Output
    include FFWD::Reporter

    set_reporter_keys :dropped_metrics, :sent_metrics, :failed_metrics

    HEADER = {
      "Content-Type" => "application/json"
    }

    API_PATH = "/api/v1/datapoints"

    def initialize core, log, url, flush_interval, buffer_limit
      @log = log
      @url = url
      @flush_interval = flush_interval
      @buffer_limit = buffer_limit
      @buffer = []
      @pending = nil
      @conn = nil

      core.output.starting do
        @log.info "Will send events to #{@url}"

        @conn = EM::HttpRequest.new(@url)

        sub = core.output.metric_subscribe do |metric|
          if @buffer.size >= @buffer_limit
            increment :dropped_metrics, 1
            next
          end

          @buffer << metric
          check_timer!
        end

        core.output.stopping do
          core.output.metric_unsubscribe sub

          if @timer
            @timer.cancel
            @timer = nil
          end
        end
      end
    end

    def id
      "kairosdb_http_output-#{@url}"
    end

    def flush!
      if @timer
        @timer.cancel
        @timer = nil
      end

      if @pending
        @log.info "Request already in progress, dropping metrics"
        increment :dropped_metrics, @buffer.size
        @buffer = []
        return
      end

      unless @conn
        @log.error "No active connection"
        increment :dropped_metrics, @buffer.size
        @buffer = []
        return
      end

      events = make_events(@buffer)
      buffer_size = @buffer.size
      @buffer = []

      events = JSON.dump(events)

      @log.info "Sending metrics to #{@url}"

      @pending = @conn.post(
        :path => API_PATH, :head => HEADER, :body => events)

      @pending.callback do
        increment :sent_metrics, buffer_size
        @pending = nil
      end

      @pending.errback do
        @log.error "Failed to submit events: #{@pending.error.exception}"
        increment :failed_metrics, buffer_size
        @pending = nil
      end
    end

    # optimized, makes the assumption that all events have the same metadata as
    # the first seen one.
    def make_events buffer
      groups = {}

      buffer.each do |metric|
        group = (groups[metric.key] ||= {
          :name => make_name(metric.key), :tags => make_tags(metric),
          :datapoints => []})
        group[:datapoints] << [(metric.time.to_f * 1000).to_i, metric.value]
      end

      return groups.values
    end

    # Warning: These are the 'bad' characters I've been able to reverse
    # engineer so far.
    def make_name key
      key = key.gsub " ", "/"
      key.gsub ":", "_"
    end

    # Warning: KairosDB ignores complete metrics if you use tags which have no
    # values, therefore I have not figured out a way to transport 'tags'.
    def make_tags metric
      tags = {
        "host" => metric.host
      }

      metric.attributes.each do |key, value|
        tags[key] = value
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
  end

  DEFAULT_URL = "http://localhost:8080"
  DEFAULT_FLUSH_INTERVAL = 10
  DEFAULT_BUFFER_LIMIT = 100000

  def self.setup_output opts, core
    url = opts[:url] || DEFAULT_URL
    flush_interval = opts[:flush_interval] || DEFAULT_FLUSH_INTERVAL
    buffer_limit = opts[:buffer_limit] || DEFAULT_BUFFER_LIMIT
    Output.new core, log, url, flush_interval, buffer_limit
  end
end
