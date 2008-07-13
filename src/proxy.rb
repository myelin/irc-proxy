require 'listener'

class Main
  def main
    Listener.new.listen_forever
  end
end

Main.new.main
