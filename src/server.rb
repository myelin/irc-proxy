class ServerConnection < AsyncSocket
  def initialize(app, conf)
    super()
    @app = app

    @host = conf['host']
    @port = conf['port']
    @ssl = conf['ssl']
    @desired_nick = conf['nick']
    @user = conf['user']
    @name = conf['name']

    @state = :offline
  end

  def start
    Thread.new do
      run
    end
  end

  def run
    puts "Server thread for #{@desired_nick}@#{@host}:#{@port} starting"

    while true
      if @state == :offline
        puts "offline, connecting"
        start_connect
      end

      poll_socket
    end

    puts "Server thread for #{@desired_nick}@#{@host}:#{@port} shut down"
  rescue Exception => e
    puts "Exception killed server thread for #{@desired_nick}@#{@host}:#{@port}: #{e}"
    puts e.backtrace.join("\n")
  end

  def start_connect
    @state = :connecting
    @server_name = @nick = nil
    @nick_serial = 0
    connect(@host, @port)
  end

  def handle_connect
    puts "connected to server!"
    @state = :logging_in
    write "NICK #{@desired_nick}"
    write "USER #{@user} #{@hostname} #{@host} :#{@name}"
  end

  def handle_line(line)
    shortargs, longarg = /^(.*?)(?: :(.*))?$/.match(line).captures
    args = shortargs.split(' ') << longarg
    puts "server: #{args.inspect}"

    if args[0][0..0] == ":"
      # commands starting with an id
      case args[1]
      when "004"
        puts "004 #{args.inspect}"
        @nick = args[2]
        @server_name = args[3]
        puts "i am #{@nick} and the server is #{@server_name}"
      when "433"
        #[":irc.iopen.net", "433", "*", "myelin", "Nickname is already in use."]
        @nick_serial += 1
        write "NICK #{@desired_nick}#{@nick_serial}"
      when "MODE"
        if args[0] == ":#{@nick}"
          puts "mode message; i'm connected"
          @state = :online
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
