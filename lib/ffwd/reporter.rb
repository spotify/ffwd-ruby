module FFWD::Reporter
  module ClassMethods
    def reporter_keys
      @reporter_keys ||= [:total]
    end

    def reporter_id
      @reporter_id ||= nil
    end

    def reporter_id_method
      @reporter_id_method ||= :reporter_id
    end

    def setup_reporter opts={}
      @reporter_keys = [:total] + (opts[:keys] || [])
      @reporter_id = opts[:reporter_id]
      @reporter_id_method = opts[:id_method] || :reporter_id
    end
  end

  def self.included mod
    mod.extend ClassMethods
  end

  def reporter_data
    @reporter_keys ||= self.class.reporter_keys
    @reporter_data ||= Hash[@reporter_keys.map{|k| [k, 0]}]
  end

  def increment n, c=1
    reporter_data[n] += c
    reporter_data[:total] += c
  end

  def report!
    @reporter_id ||= (
      self.class.reporter_id || send(self.class.reporter_id_method))

    reporter_data.each do |k, v|
      yield "#{@reporter_id}/#{k}", v
      reporter_data[k] = 0
    end
  end
end
