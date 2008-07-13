class ServerConnection < AsyncSocket
  def initialize(app, conf)
    super()
    @app = app

    @host = conf['host']
    @port = conf['port']
    @ssl = conf['ssl']

    @nick = conf['nick']
  end

  def start
    Thread.new do
      run
    end
  end

  def run
    puts "Server thread for #{@nick}@#{@host}:#{@port} starting"

    @state = :offline

    while false
      s = IO.select([@sock], @client_wbuffer.empty? ? [] : [@sock], [], 1)
      next if s.nil?
      r, w, e = *s
    end

    puts "Server thread for #{@nick}@#{@host}:#{@port} shut down"
  rescue Exception => e
    puts "Exception killed server thread for #{@nick}@#{@host}:#{@port}: #{e}"
    puts e.backtrace.join("\n")
  end
end
