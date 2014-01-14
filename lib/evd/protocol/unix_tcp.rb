module EVD::UnixTCP
  class Bind
    def initialize(log, path, handler, *args)
      @log = log
      @path = path
      @handler = handler
      @args = args
    end

    def start input, output
      @log.info "Binding to unix+udp://#{@path}"

      File.unlink @path if File.exists? @path

      s = Socket.new(Socket::AF_UNIX, Socket::SOCK_STREAM, 0)
      s.bind(Socket.pack_sockaddr_un(@path))

      EM.attach(s, @handler, input, output, *@args)
    end
  end

  def self.family; :tcp; end

  def self.bind log, opts, handler, *args
    raise "Missing configuration ':path'" if (path = opts[:path]).nil?
    Bind.new log, path, handler, *args
  end
end
