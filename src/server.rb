class ServerConnection < AsyncSocket
  def initialize(app, conf)
    super()
    @app = app

    @host = conf['host']
    @port = conf['port']
    @ssl = conf['ssl']

    @nick = conf['nick']

    @state = :offline
  end

  def start
    Thread.new do
      run
    end
  end

  def run
    puts "Server thread for #{@nick}@#{@host}:#{@port} starting"

    while true
      case @state
      when :offline
        puts "offline, connecting"
        connect(@host, @port)
        @state = :connecting
      when :connecting
        raise Exception, "should be connecting and not connected in connecting state" if @connected || !@connecting
      when :logging_in
        #TODO
      else
        raise Exception, "invalid state #{@state}"
      end

      poll_socket
    end

    puts "Server thread for #{@nick}@#{@host}:#{@port} shut down"
  rescue Exception => e
    puts "Exception killed server thread for #{@nick}@#{@host}:#{@port}: #{e}"
    puts e.backtrace.join("\n")
  end

  def handle_connect
    puts "connected to server!"
    @state = :logging_in
  end

  def handle_line(line)
    puts "server said: #{line}"
  end
end
