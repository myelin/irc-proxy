class ClientConnection < AsyncSocket
  def initialize(app, sock)
    super()
    @app = app
    @sock = sock
    @users = app.conf['users']

    @connected = true
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
      umsg ["JOIN", chan] # tell the user they're joined
      msg "332", [chan, "channel title"]
      msg "353", ["=", chan, "userone usertwo userthree"]
      msg "366", [chan, "End of /NAMES list"]
    elsif line == 'AWAY'
      @away = true
    else
      puts "can't parse #{line}"
    end
  end

  def try_register
    return unless @client_user && @client_pass && @client_nick
    msg "001", ["Welcome to the proxy #{@client_nick}!#{@client_user}@#{@client_host}"]
    msg "002", ["Your host is #{@hostname}, running Phil's Ruby IRC proxy"]
    msg "003", ["This server was created #{@timestamp.to_s}"]
    msg "004", [@hostname, "0.01", "iowghraAsORTVSxNCWqBzvdHtGp", "lvhopsmntikrRcaqOALQbSeIKVfMCuzNTGj"]
    
    # copied from an Unreal server
    msg "005", ["NAMESX", "SAFELIST", "HCN", "MAXCHANNELS=10", "CHANLIMIT=#:10", "MAXLIST=b:60,e:60,I:60", "NICKLEN=30", "CHANNELLEN=32", "TOPICLEN=307", "KICKLEN=307", "AWAYLEN=307", "MAXTARGETS=20", "WALLCHOPS", "are supported by this server"]
    msg "251", ["There are 7 users and 8 invisible on 2 servers"]
    msg "252", ["8", "operator(s) online"]
    msg "254", ["4", "channels formed"]
    msg "255", ["I have 7 clients and 1 servers"]
    msg "265", ["Current Local Users: 7  Max: 15"]
    msg "266", ["Current Global Users: 15  Max: 23"]
    msg "422", ["MOTD File is missing"]
    
    msg_from @client_nick, "MODE", @client_nick, ["+iwx"]
    @registered = true
  end

  def msg(cmd, args)
    msg_from @hostname, cmd, @client_nick, args
  end

  def umsg(args)
    raw_msg([":#{@client_nick}!#{@client_login}@your.host"] + args)
  end

  def msg_from(from, cmd, to, args)
    raw_msg([":#{from}", cmd, to] + args)
  end

  def raw_msg(args)
    unless args[-1].index(' ').nil?
      args[-1] = ':' + args[-1]
    end
    write(args * " ")
  end

  def send_err(err)
    write "error: #{err}"
  end

  def send_numeric(code, txt)
    write ":#{@hostname} #{code} #{@client_nick} #{txt}"
  end

  def send_msg(msg)
    write ":#{@hostname} #{Time.now.to_i - @timestamp} #{@client_nick} :#{msg}"
  end
end
