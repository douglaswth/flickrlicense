require 'flickr/login'
require 'flickraw'
require 'pry'
require 'sinatra'
require 'sinatra/config_file'
require 'sinatra/json'
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

class User < Sequel::Model
  one_to_many :photo, key: :owner
  unrestrict_primary_key
end

class License < Sequel::Model
  one_to_many :photo, key: :license
  unrestrict_primary_key
end

class Photo < Sequel::Model
  many_to_one :user, key: :owner
  many_to_one :license, key: :license
  unrestrict_primary_key
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
  @user = User.find_or_create(nsid: flickr_user[:user_nsid]) do |user|
    user.username = flickr_user[:username]
    user.fullname = flickr_user[:fullname]
  end
end

get '/' do
  flickr.photos.licenses.getInfo.each do |flickr_license|
    License.create do |license|
      license.id = flickr_license.id
      license.name = flickr_license.name
      license.url = flickr_license.url
    end
  end if License.count == 0
  erb :index
end

get '/logout' do
  flickr_clear
  redirect to('/')
end

get %r{/photos/([1-8])} do |page|
  page, per_page = page.to_i, 500
  photos = flickr.photos.search(user_id: :me, extras: 'license', per_page: per_page, page: page)
  json page: page, per_page: per_page, photos: photos
end
