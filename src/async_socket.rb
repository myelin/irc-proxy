# Asynchronous socket class - kinda like asyncore/asynchat in Python
# Copyright (C) 2008 Phillip Pearson <pp@myelin.co.nz>

class SocketClosed < Exception; end

class AsyncSocket
  def initialize
    @hostname = Socket::gethostname
    @rbuffer = []
    @wbuffer = []
    @connected = false # we have a valid socket
    @connecting = false # connect_nonblock() has been called
    @sock = nil
  end

  def poll_socket
    puts "select"
    s = IO.select([@sock], # readable
                  (@connected && @wbuffer.empty?) ? [] : [@sock], # writable
                  @connected ? [@sock] : [], # error
                  1)
    return if s.nil?
    r, w, e = *s
    raise Exception, "internal error - socket #{@sock} appeared in exception list from IO.select and i don't know what to do!" if e.include? @sock

    #puts "state: #{@connecting} #{r.inspect} #{w.inspect} #{e.inspect}"

    # if writable
    if w.include? @sock
      if @connecting
        @connecting = false
        @connected = true
        handle_connect
      end
      until @wbuffer.empty?
        d = @wbuffer.shift
        puts "sending #{d}"
        written = @sock.write_nonblock(d)
        if written < d.length
          # put the rest of the line back into the buffer
          @wbuffer.unshift d[written+1..-1]
          puts "didn't manage to send it all, putting this back in the send buffer: #{@wbuffer[0]}"
          break
        end
      end
    end
    
    # if readable
    if r.include? @sock
      d = @sock.recv_nonblock(1024)
      raise SocketClosed if d == ''
      
      p = d.rindex("\n")
      if p.nil?
        @rbuffer << d
      else
        @rbuffer << d[0..p]
        lines = (@rbuffer * "").split("\n")
        @rbuffer = [d[p+1..-1]]
        lines.each do |line|
          handle_line line.chomp
        end
      end
    end
  end

  def handle_line(line)
    raise NotImplementedError, "handle_line is an abstract method"
  end

  def handle_connect
    raise NotImplementedError, "handle_connect is an abstract method"
  end

  def write(s)
    puts "buffering: #{s.inspect}"
    @wbuffer << s + "\n"
  end

  def write_raw(s)
    puts "buffering: #{s.inspect}"
    @wbuffer << s
  end

  def connect(host, port)
    @connecting = true
    @connected = false
    @sock = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    begin
      @sock.connect_nonblock(Socket.sockaddr_in(port, host))
      @connecting = false # unlikely
      @connected = true
    rescue Errno::EINPROGRESS
      # poll_socket will pick up the connection
    end
    handle_connect if @connected
  end
end
