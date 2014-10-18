require 'rack/session/redis'

if redis_url = ENV['REDIS_URL'] || ENV['REDISTOGO_URL']
  use Rack::Session::Redis, redis_server: redis_url
end

require './app'
run Sinatra::Application
