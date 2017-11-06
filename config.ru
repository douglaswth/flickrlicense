require_relative 'app'
require 'flickr/login'
require 'pathname'

flickr = Flickr::Login.new(settings.flickr_api_key, settings.flickr_shared_secret)
flickr_endpoint = flickr.login_handler(return_to: '/')

use Rack::Session::Cookie, secret: settings.session_secret
run Rack::URLMap.new('/' => Sinatra::Application, '/login' => flickr_endpoint)
