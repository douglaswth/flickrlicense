require 'flickr/login'
require 'flickraw'
require 'sinatra'
require 'sinatra/config_file'
require 'sinatra/reloader'
require 'sinatra/sequel'

config_file 'config.yml'

enable :sessions

set :database, 'sqlite://db.sqlite3'

migration 'create users, licenses, and photos tables' do
  database.create_table :users do
    column :nsid, String, primary_key: true
    column :username, String
    column :fullname, String
  end

  database.create_table :licenses do
    column :id, Integer, primary_key: true
    column :name, String
    column :url, String
  end

  database.create_table :photos do
    column :id, Integer, primary_key: true
    foreign_key :owner, :users
    foreign_key :license, :licenses
    column :json, 'text'
    column :ignore, 'boolean'
  end
end

helpers Flickr::Login::Helpers
helpers do
  def flickr
    unless @flickr
      @flickr = FlickRaw::Flickr.new(api_key: settings.flickr_api_key, shared_secret: settings.flickr_shared_secret)
      @flickr.access_token, @flickr.access_secret = flickr_access_token
    end
    @flickr
  end
end

before do
  redirect to('/login?perms=write') unless flickr_user
end

get '/' do
  erb :index
end

get '/logout' do
  flickr_clear
  redirect to('/')
end

=begin
def list(user)
  all_photos = []
  page = 0
  begin
    photos = flickr.photos.search(user_id: user, extras: 'license', per_page: 500, page: page += 1)
    all_photos.push(*photos.to_a)
  end until photos.size < 500
  all_photos
end
=end
