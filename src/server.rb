class ServerConnection < AsyncSocket
  attr_reader :host, :channels

  def initialize(app, host, conf)
    super()
    @app = app

    @host = host
    @port = conf['port']
    @ssl = conf['ssl']
    @online_nick = conf['nick']
    @away_nick = conf['awaynick'] || @online_nick
    @user = conf['user']
    @name = conf['name']
    @channels_to_join = conf['channels']
    @channels = {}

    @state = :offline
  end

  def start
    Thread.new do
      run
    end
  end

  def desired_nick
    @online_nick
  end

  def run
    puts "Server thread for #{desired_nick}@#{@host}:#{@port} starting"

    while true
      if @state == :offline
        puts "offline, connecting"
        start_connect
      end

      poll_socket
    end

    puts "Server thread for #{desired_nick}@#{@host}:#{@port} shut down"
  rescue Exception => e
    puts "Exception killed server thread for #{desired_nick}@#{@host}:#{@port}: #{e}"
    puts e.backtrace.join("\n")
  end

  def start_connect
    @state = :connecting
    @server_name = @nick = nil
    @nick_serial = 0
    connect(@host, @port)
  end

  def join_channels
    @channels_to_join.each do |chan|
      puts "joining #{chan}"
      write "JOIN #{chan}"
    end
  end

  def handle_connect
    puts "connected to server #{@host}!"
    @state = :logging_in
    write "NICK #{desired_nick}"
    write "USER #{@user} #{@hostname} #{@host} :#{@name}"
  end

  def send_chanmsg(chan, msg)
    # send a message received from a client to a channel
    write "PRIVMSG #{chan} :#{msg}"
  end

  def handle_line(line)
    shortargs, longarg = /^(.*?)(?: :(.*))?$/.match(line).captures
    args = shortargs.split(' ') << longarg
    puts "#{@host}: #{args.inspect}"

    if args[0][0..0] == ":"
      # commands starting with an id
      case args[1]
      when "004"
        puts "004 #{args.inspect}"
        @nick = args[2]
        @server_name = args[3]
        puts "i am #{@nick} and the server is #{@server_name}"
      when "433"
        #[":servername", "433", "*", "myelin", "Nickname is already in use."]
        @nick_serial += 1
        write "NICK #{desired_nick}#{@nick_serial}"
      when "MODE"
        if args[0] == ":#{@nick}"
          puts "mode message; i'm connected!"
          @state = :online
          join_channels
        end
      when "JOIN"
        chan = args[2]
        puts "i've joined a channel: #{chan}"
        @channels[chan] = {'topic' => nil, 'names' => []}
      when "332"
        @channels[args[3]]['topic'] = args[4]
      when "333"
        # channel owner?
      when "353"
        @channels[args[4]]['names'] += args[5].split(" ")
      when "366"
        # end of /NAMES list
      when "PRIVMSG"
        #[":nick!user@user.host.com", "PRIVMSG", "#channel", "lol"]
        from, _, to, msg = args
        nick, user, host = /^:(.*?)!(.*?)@(.*?)$/.match(from).captures
        if to == @nick
          @app.handle_privmsg(self, nick, msg)
        elsif to[0..0] == '#'
          @app.handle_chanmsg(self, to, nick, msg)
        else
          puts "unknown privmsg! <#{nick}> -> <#{to}>: #{msg}"
        end
      end
    else
      # commands not starting with an id
      case args[0]
      when "PING"
        write "PONG :#{args[1]}"
      end
    end
  end
end
