class Client
  def initialize(sock)
    @sock = sock
    @client_rbuffer = []
  end

  def start
    puts "Starting new client for socket #{@sock}"
    Thread.new do
      run
    end
  end

  def run
    puts "in the thread now"
    while true
      print "read from socket"
      IO.select([@sock])
      d = @sock.recv_nonblock(1024)
      break if d == ''

      p = d.rindex("\n")
      if p.nil?
        @client_rbuffer << d
      else
        @client_rbuffer  << d[0..p]
        lines = (@client_rbuffer * "").split("\n")
        @client_rbuffer = [d[p+1..-1]]
        lines.each do |line|
          handle_line line.chomp
        end
      end
    end
    puts "socket closed - thread finished"
  end

  def handle_line(line)
    puts "line: #{line}"
  end
end
