#!/usr/bin/env ruby

require 'yaml'
require 'socket'
require 'pp'

require 'async_socket'
require 'listener'
require 'server'
require 'client'

class App
  def main
    read_config
    start_server_connections
    Listener.new(self).listen_forever
  end

  def read_config
    @conf = YAML.load(IO.read("config.yml"))
  end

  def start_server_connections
    @conf['servers'].each do |s|
      ServerConnection.new(self, s).start
    end
  end
end

App.new.main
