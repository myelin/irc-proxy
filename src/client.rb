require 'socket'

class Client
  def initialize(sock)
    @hostname = Socket::gethostname

    @timestamp = Time.now
    @sock = sock
    @client_rbuffer = []
    @client_wbuffer = []

    @client_user = @client_host = @client_login = @client_name = @client_pass = @client_nick = nil
    @registered = false
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
    send_numeric "001", ":Welcome to the proxy #{@client_nick}!#{@client_user}@#{@client_host}"
    send_numeric "002", ":Your host is #{@hostname}, running Phil's Ruby IRC proxy"
    send_numeric "003", ":This server was created #{@timestamp.to_s}"
    send_numeric "004", ":#{@hostname} 0.01 iowghraAsORTVSxNCWqBzvdHtGp lvhopsmntikrRcaqOALQbSeIKVfMCuzNTGj"

    # copied from irc.iopen.net
    send_numeric "005", "NAMESX SAFELIST HCN MAXCHANNELS=10 CHANLIMIT=#:10 MAXLIST=b:60,e:60,I:60 NICKLEN=30 CHANNELLEN=32 TOPICLEN=307 KICKLEN=307 AWAYLEN=307 MAXTARGETS=20 WALLCHOPS :are supported by this server"
    send_numeric "251", ":There are 7 users and 8 invisible on 2 servers"
    send_numeric "252", "8 :operator(s) online"
    send_numeric "254", "4 :channels formed"
    send_numeric "255", ":I have 7 clients and 1 servers"
    send_numeric "265", ":Current Local Users: 7  Max: 15"
    send_numeric "266", ":Current Global Users: 15  Max: 23"
    send_numeric "422", ":MOTD File is missing"

    send_raw ":#{@client_nick} MODE #{@client_nick} :+iwx"
    @registered = true
  end

  def send_err(err)
    send_raw "error: #{err}"
  end

  def send_numeric(code, txt)
    send_raw ":#{@hostname} #{code} #{@client_nick} #{txt}"
  end

  def send_msg(msg)
    send_raw ":#{@hostname} #{Time.now.to_i - @timestamp} #{@client_nick} :#{msg}"
  end

  def send_raw(txt)
    #puts "buffering #{txt}"
    @client_wbuffer << txt + "\n"
  end
end
