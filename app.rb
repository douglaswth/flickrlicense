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
    # foreign_key :user_id, :users
    foreign_key :owner, :users
    # foreign_key :license_id, :licenses
    foreign_key :license, :licenses
    column :json, 'text'
    column :ignore, 'boolean'
  end
end

migration 'rename photo owner and license columns to user_id and license_id' do
  database.alter_table :photos do
    drop_foreign_key [:owner]
    rename_column :owner, :user_id
    add_foreign_key [:user_id], :users
    drop_foreign_key [:license]
    rename_column :license, :license_id
    add_foreign_key [:license_id], :licenses
  end
end

class User < Sequel::Model
  one_to_many :photo
  unrestrict_primary_key
end

class License < Sequel::Model
  one_to_many :photo
  unrestrict_primary_key
end

class Photo < Sequel::Model
  many_to_one :user
  many_to_one :license
  unrestrict_primary_key

  def flickraw
    @flickraw ||= OpenStruct.new(JSON.parse(json))
  end

  def as_json(*)
    {
      id: id,
      license: license_id,
      ignore: ignore,
      image: FlickRaw.url_q(flickraw),
      link: FlickRaw.url_photopage(flickraw),
    }
  end

  def to_json(*args)
    as_json.to_json(*args)
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
  photos = Photo.reverse(:id).limit(per_page, (page - 1) * per_page).all
  begin
    photos = flickr.photos.search(user_id: :me, extras: 'license', per_page: per_page, page: page).map do |flickr_photo|
      Photo.create do |photo|
        photo.id = flickr_photo.id
        photo.user_id = flickr_photo.owner
        photo.license_id = flickr_photo.license
        photo.json = flickr_photo.to_hash.to_json
        photo.ignore = false
      end
    end if photos.count == 0
  rescue Sequel::UniqueConstraintViolation
    # sometimes the Flickr API will just keep repeating the same results for subsequent pages
  end
  json path: "/photos/#{page + 1}", photos: photos if photos.count == per_page && page < 8
  json photos: photos
end
