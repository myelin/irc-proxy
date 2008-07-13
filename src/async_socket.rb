# Asynchronous socket class - kinda like asyncore/asynchat in Python
# Copyright (C) 2008 Phillip Pearson <pp@myelin.co.nz>

class SocketClosed < Exception; end

class AsyncSocket
  def initialize
    @rbuffer = []
    @wbuffer = []
  end

  def poll_socket
    puts "select"
    s = IO.select([@sock], @wbuffer.empty? ? [] : [@sock], [], 1)
    return if s.nil?
    r, w, e = *s
    
    # if writable
    if w.include? @sock
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

  def handle_line
    raise NotImplementedError, "handle_line is an abstract method"
  end

  def write(s)
    @wbuffer << s
  end
end
