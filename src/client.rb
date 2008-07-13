require 'socket'

class Client
  def initialize(sock)
    @hostname = Socket::gethostname

    @timestamp = Time.now.to_i
    @sock = sock
    @client_rbuffer = []
    @client_wbuffer = []

    @client_user = @client_host = @client_login = @client_name = @client_pass = @client_nick = nil
  end

  def start
    puts "Starting new client for socket #{@sock}"
    Thread.new do
      run
    end
  end

  def run
    while true
      puts "select"
      s = IO.select([@sock], @client_wbuffer.empty? ? [] : [@sock], [], 1)
      next if s.nil?
      r, w, e = *s

      # if writable
      if w.include? @sock
        until @client_wbuffer.empty?
          d = @client_wbuffer.shift
          puts "sending #{d}"
          written = @sock.write_nonblock(d)
          if written < d.length
            # put the rest of the line back into the buffer
            @client_wbuffer.unshift d[written+1..-1]
            puts "didn't manage to send it all, putting this back in the send buffer: #{@client_wbuffer[0]}"
            break
          end
        end
      end

      # if readable
      if r.include? @sock
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
    end
    puts "socket closed - thread done"
  rescue Exception => e
    puts "Exception in thread: #{e}"
    puts e.backtrace.join("\n")
  end

  def handle_line(line)
    puts "line: #{line}"
    if m = /^USER (.*?) (.*?) (.*?) :(.*)$/.match(line)
      @client_user, @client_host, @client_login, @client_name = m.captures
      try_register
    elsif m = /^PASS (.*)$/.match(line)
      @client_pass = m.captures[0]
    elsif m = /^NICK (.*)$/.match(line)
      @client_nick = m.captures[0]
      try_register
    else
      puts "can't parse #{line}"
    end
  end

  def try_register
    return unless @client_user && @client_pass && @client_nick
    send_msg "Welcome to the proxy!"
    send_raw ":#{@client_nick} MODE #{@client_nick} :+iwx"
  end

  def send_err(err)
    send_raw "error: #{err}"
  end

  def send_msg(msg)
    send_raw ":#{@hostname} #{Time.now.to_i - @timestamp} #{@client_nick} :#{msg}"
  end

  def send_raw(txt)
    #puts "buffering #{txt}"
    @client_wbuffer << txt + "\n"
  end
end
