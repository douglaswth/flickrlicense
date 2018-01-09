#   flickrlicense -- A thingy to update Flickr photo licenses
#   Copyright (C) 2017  Douglas Thrift
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published
#   by the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

require_relative 'app'
require 'flickr/login'
require 'pathname'

flickr = Flickr::Login.new(settings.flickr_api_key, settings.flickr_shared_secret)
flickr_endpoint = flickr.login_handler(return_to: '/')

use Rack::Session::Cookie, secret: settings.session_secret
run Rack::URLMap.new('/' => Sinatra::Application, '/login' => flickr_endpoint)
