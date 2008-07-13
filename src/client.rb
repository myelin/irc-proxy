class ClientConnection < AsyncSocket
  def initialize(app, sock)
    super()
    @app = app
    @sock = sock
    @connected = true

    @hostname = Socket::gethostname

    @timestamp = Time.now

    @client_user = @client_host = @client_login = @client_name = @client_pass = @client_nick = nil
    @registered = false

    @channels = []
    @away = false
  end

  def start
    Thread.new do
      run
    end
  end

  def run
    puts "Client thread for socket #{@sock} starting"
    while true
      poll_socket
    end
    puts "Client thread for socket #{@sock} shut down"
  rescue Exception => e
    puts "Exception killed client thread for #{@sock}: #{e}"
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
    elsif m = /^JOIN (#[a-z0-9]+)$/.match(line)
      chan = m.captures[0]
      puts "join channel #{chan}"
    elsif line == 'AWAY'
      @away = true
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

    write ":#{@client_nick} MODE #{@client_nick} :+iwx\n"
    @registered = true
  end

  def send_err(err)
    write "error: #{err}\n"
  end

  def send_numeric(code, txt)
    write ":#{@hostname} #{code} #{@client_nick} #{txt}\n"
  end

  def send_msg(msg)
    write ":#{@hostname} #{Time.now.to_i - @timestamp} #{@client_nick} :#{msg}\n"
  end
end
