require 'webrick'
require 'webrick/httpproxy'
require 'set'
require 'open-uri'

AD_SERVERS = "http://pgl.yoyo.org/adservers/serverlist.php?hostformat=nohtml&showintro=1&startdate%5Bday%5D=&startdate%5Bmonth%5D=&startdate%5Byear%5D=&mimetype=plaintext"

class AdBlockProxy < WEBrick::HTTPProxyServer

  def initialize(options)
  	super
  	@blocked = Set.new
    @running = true
  end

  def load_ad_servers
    open(AD_SERVERS) { 
      |io| data = io.read 
      data.each_line do |line|
        line.strip!
        @blocked.add line
      end
    }
  end

  def do_GET(request, response)
    if "adblock.proxy" == request.host
      if request.query['pause']
        logger.info "AdBlock paused"
        @running = false
      elsif request.query['resume']
        logger.info "AdBlock resumed"
        @running = true
      elsif request.query['reload']
        logger.info "AdBlock reload"
        @blocked = Set.new
        load_ad_servers
      end
      response.status = 200
      response.body = "Status: #{@running ? 'Running' : 'Paused'}"
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
  	  super
  	end
  end

  def blocked?(host)
    if @running
  	  hosts = host.split('.')
  	  while !hosts.empty?
  		  hostname = hosts.join '.'
  		  return true if @blocked.include?(hostname)
  		  hosts.shift
  	  end
    end
  	false
  end

end

server = AdBlockProxy.new(:Port => 8081, :AccessLog => [])

trap("INT"){server.shutdown}
trap("TERM"){server.shutdown}

server.load_ad_servers

server.start
