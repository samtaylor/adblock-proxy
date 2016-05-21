require 'webrick'
require 'webrick/httpproxy'
require 'set'

NEWLINE = "\r\n"

class AdBlockProxy < WEBrick::HTTPProxyServer

  def initialize(options)
  	super
  	@blocked = Set.new
  end

  def load_blocked(filename)
    logger.info("Loading #{filename}")
  	File.open(filename).each_line do |line|
  	  line.strip!
  	  logger.info "#{line} already blocked" unless @blocked.add? line
  	end
  end

  def do_GET(request, response)
    if "adblock.proxy" == request.host
      response.status = 200
      response.body = "OK"
      return
    end

    if blocked? request.host
      logger.info "BLOCK #{request.host}"
      response.status = 204
      response.keep_alive = false
    else
      super
    end
  end

  def do_CONNECT(request, response)
  	host = request.header["host"].first
  	if blocked? host
      logger.info "BLOCK #{host}"
  	  response.status = 204
  	  response.keep_alive = false
  	else
      logger.info "ALLOW #{host}"
  	  super
  	end
  end

  def blocked?(host)
  	hosts = host.split('.')
  	while !hosts.empty?
  		hostname = hosts.join '.'
  		return true if @blocked.include?(hostname)
  		hosts.shift
  	end
  	false
  end

end

server = AdBlockProxy.new(:Port => 3126, :AccessLog => [])

trap("INT"){server.shutdown}
trap("TERM"){server.shutdown}

server.load_blocked 'adservers'

server.start
