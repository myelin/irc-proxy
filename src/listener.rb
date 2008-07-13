require 'socket'

require 'client'

class Listener
  def initialize
    @threads = []
  end

  def listen_forever
    @serv = TCPServer.new(6667)
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
