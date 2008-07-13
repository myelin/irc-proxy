require 'socket'

require 'client'

class Listener
  def initialize
    @threads = []
    @port = 6667
  end

  def listen_forever
    puts "Listening on port #{@port} for IRC clients ..."
    @serv = TCPServer.new(@port)
    while true
      begin
        sock = @serv.accept_nonblock
        @threads << Client.new(sock).start
      rescue Errno::EAGAIN, Errno::EWOULDBLOCK, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
        IO.select([@serv], [], [], 1)
        retry
      end
    end
  end
end
