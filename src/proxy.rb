#!/usr/bin/env ruby

require 'yaml'
require 'socket'
require 'pp'

require 'async_socket'
require 'listener'
require 'server'
require 'client'

class App
  attr_reader :conf

  def initialize
    @servers = {}
    @clients = []
  end

  def main
    read_config
    start_server_connections
    Listener.new(self).listen_forever
  end

  def new_client(c)
    @clients << c
  end

  def client_disconnected(c)
    puts "removing client from list"
    @clients.delete(c)
  end

  def read_config
    @conf = YAML.load(IO.read("config.yml"))
    @buffer_path = @conf['global']['buffers']
    Dir.mkdir(@buffer_path) unless File.exist?(@buffer_path)
  end

  def start_server_connections
    @conf['servers'].each do |host, s|
      next if s['disabled']
      @servers[host] = c = ServerConnection.new(self, host, s)
      c.start
    end
  end

  def handle_privmsg(server, from, msg)
    puts "<#{server.host}> #{from}: #{msg}"
  end

  def send_privmsg(to, msg)
    puts "halp!  don't know how to route a privmsg to #{to} (#{msg})"
  end

  def handle_chanmsg(server, chan, from, msg)
    puts "<#{server.host}> #{chan}/#{from}: #{msg}"
    c = find_client_on_channel(chan)
    if c
      c.handle_chanmsg(server, chan, from, msg)
    else
      puts "buffering message on server #{server.host} channel #{chan}"
      File.open("#{@buffer_path}/#{server.host}.buffer", "a") do |f|
        f.write "SERVER #{server.host} CHANNEL #{chan} MSG #{msg}\n"
      end
    end
  end

  def send_chanmsg(chan, msg)
    puts "channel msg to #{chan}: #{msg}"
    # figure out where this channel lives
    # and send it...
    s = find_channel(chan)
    puts "failed to send chanmsg to #{chan}" and return unless s
    s.send_chanmsg(chan, msg)
  end

  def find_channel(chan)
    @servers.each do |host, s|
      return s if s.channels.include?(chan)
    end
    nil
  end

  def find_client_on_channel(chan)
    @clients.each do |c|
      return c if c.channels.include?(chan)
    end
    nil
  end
    
end

App.new.main
