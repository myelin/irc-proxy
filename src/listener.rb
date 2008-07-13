class Listener
  def initialize(app)
    @app = app
    @port = 6667
  end

  def listen_forever
    puts "Listening on port #{@port} for IRC clients ..."
    @serv = TCPServer.new(@port)
    while true
      begin
        sock = @serv.accept_nonblock
        c = ClientConnection.new(@app, sock)
        @app.new_client(c)
        c.start
      rescue Errno::EAGAIN, Errno::EWOULDBLOCK, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
        IO.select([@serv], [], [], 1)
        retry
      end
    end
  end
end
