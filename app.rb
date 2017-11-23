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
    # foreign_key :user_id, :users, on_delete: :cascade, on_update: :restrict
    foreign_key :owner, :users
    # foreign_key :license_id, :licenses, on_delete: :cascade, on_update: :restrict
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

migration 'add on delete and update constraints to photo user_id and license_id' do
  database.alter_table :photos do
    drop_foreign_key [:user_id]
    add_foreign_key [:user_id], :users, on_delete: :cascade, on_update: :restrict
    drop_foreign_key [:license_id]
    add_foreign_key [:license_id], :licenses, on_delete: :cascade, on_update: :restrict
  end
end

migration 'add not null constraint to photo user_id and license_id' do
  database.alter_table :photos do
    set_column_not_null :user_id
    set_column_not_null :license_id
  end
end

class User < Sequel::Model
  one_to_many :photos
  unrestrict_primary_key
end

class License < Sequel::Model
  one_to_many :photos
  unrestrict_primary_key

  def as_json(*)
    {
      id: id,
      name: name,
      url: url,
    }
  end

  def to_json(*args)
    as_json.to_json(*args)
  end
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
      img: FlickRaw.url_q(flickraw),
      url: FlickRaw.url_photopage(flickraw),
      title: flickraw.title,
      public: flickraw.ispublic != 0,
      friend: flickraw.isfriend != 0,
      family: flickraw.isfamily != 0,
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
  @licenses = License.all
  @licenses = flickr.photos.licenses.getInfo.map do |flickr_license|
    License.create do |license|
      license.id = flickr_license.id
      license.name = flickr_license.name
      license.url = flickr_license.url
    end
  end if @licenses.count == 0
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
        photo.user = @user
        photo.license_id = flickr_photo.license
        photo.json = flickr_photo.to_hash.to_json
        photo.ignore = false
      end
    end if photos.count == 0
  rescue FlickRaw::Error => e
    halt 422, json(error: e.message)
  rescue Sequel::UniqueConstraintViolation
    # sometimes the Flickr API will just keep repeating the same results for subsequent pages
  end
  json path: "/photos/#{page + 1}", photos: photos if photos.count == per_page && page < 8
  json photos: photos
end

post '/photos' do
  ignore = params['ignore'] == 'true'
  ids = params['photos'] && params['photos'].is_a?(Array) ? params['photos'] : [params['photo']]
  photos = @user.photos_dataset.where(id: ids)
  halt 404, json(error: "Could not find photo(s) with ID(s): #{ids.map(&:to_i) - photos.map(:id)}") unless photos.count == ids.size
  photos.update(ignore: ignore)
  status 204
end

post '/photos/*' do |id|
  photo = @user.photos_dataset.where(id: id).first
  halt 404, json(error: "Could not find photo with ID: #{id}") unless photo
  license_id = params['license'] && params['license'].to_i
  license = License[license_id]
  halt 422, json(error: "Could not find license with ID: #{license_id.inspect}") unless license
  halt 422, json(error: "Could not change license of ignored photo") if photo.ignore
  begin
    flickr.photos.licenses.setLicense(photo_id: photo.id, license_id: license.id)
  rescue FlickRaw::Error => e
    halt 422, json(error: e.message)
  end
  photo.update(license: license)
  status 204
end
