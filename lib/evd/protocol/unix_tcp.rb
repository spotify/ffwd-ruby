module EVD::UnixTCP
  class Listen
    def initialize(log, path, handler, *args)
      @log = log
      @path = path
      @handler = handler
      @args = args
    end

    def start(buffer)
      @log.info "Listening on unix+udp://#{@path}"

      File.unlink @path if File.exists? @path

      s = Socket.new(Socket::AF_UNIX, Socket::SOCK_STREAM, 0)
      s.bind(Socket.pack_sockaddr_un(@path))

      EventMachine.attach(s, @handler, buffer, *@args)
    end
  end

  def self.family; :tcp; end

  def self.listen(log, opts, handler, *args)
    raise "Missing configuration ':path'" if (path = opts[:path]).nil?
    Listen.new log, path, handler, *args
  end
end
