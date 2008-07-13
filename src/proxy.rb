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

  def main
    read_config
    start_server_connections
    Listener.new(self).listen_forever
  end

  def read_config
    @conf = YAML.load(IO.read("config.yml"))
  end

  def start_server_connections
    @conf['servers'].each do |host, s|
      next if s['disabled']
      ServerConnection.new(self, host, s).start
    end
  end

  def handle_privmsg(server, from, msg)
    puts "<#{server.host}> #{from}: #{msg}"
  end

  def handle_chanmsg(server, chan, from, msg)
    puts "<#{server.host}> #{chan}/#{from}: #{msg}"
  end
    
end

App.new.main
