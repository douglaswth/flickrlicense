require 'flickr/login'
require 'flickraw'
require 'pry'
require 'sequel_enum'
require 'sinatra'
require 'sinatra/config_file'
require 'sinatra/json'
require 'sinatra/reloader'
require 'sinatra/sequel'

config_file 'config.yml'

enable :sessions

set :database, 'sqlite://db.sqlite3'

FlickRaw.api_key = settings.flickr_api_key
FlickRaw.shared_secret = settings.flickr_shared_secret

migration 'create users, licenses, and photos tables' do
  database.create_table :users do
    column :nsid, String, primary_key: true
    column :username, String
    column :fullname, String
    # column :json, 'text'
    # foreign_key :show_license_id, :licenses, null: true, on_delete: :set_null, on_update: :restrict
    # column :show_privacy, Integer, default: 0, null: false
    # column :show_ignored, 'boolean', default: true, null: false
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
    # column :public, 'boolean'
    # column :friend, 'boolean'
    # column :family, 'boolean'
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

migration 'add json field to user' do
  database.alter_table :users do
    add_column :json, 'text'
  end
  database.select(:nsid).from(:users).select_map(:nsid).each do |nsid|
    info = OpenStruct.new(flickr.people.getInfo(user_id: nsid).to_hash)
    info.timezone = info.timezone.to_hash
    info.photos = info.photos.to_hash
    database.from(:users).where(nsid: nsid).update(json: info.to_h.to_json)
  end
end

migration 'add show license/privacy/ignored fields to user' do
  database.alter_table :users do
    add_foreign_key :show_license_id, :licenses, null: true, on_delete: :set_null, on_update: :restrict
    add_column :show_privacy, Integer, default: 0, null: false
    add_column :show_ignored, 'boolean', default: true, null: false
  end
end

migration 'add public/friend/family fields to photos' do
  database.alter_table :photos do
    add_column :public, 'boolean'
    add_column :friend, 'boolean'
    add_column :family, 'boolean'
  end
  database.select(:id, :json).from(:photos).select_map([:id, :json]).each do |id, json|
    photo = OpenStruct.new(JSON.parse(json))
    database.from(:photos).where(id: id).update(public: photo.ispublic != 0, friend: photo.isfriend != 0, family: photo.isfamily != 0)
  end
end

class User < Sequel::Model
  plugin :enum
  one_to_many :photos
  many_to_one :show_license, class: :License
  enum :show_privacy, [:all, :public, :friends_family, :friends, :family, :private]
  unrestrict_primary_key

  def flickraw
    @flickraw ||= OpenStruct.new(JSON.parse(json))
  end

  def buddyicon
    if flickraw.iconserver.to_i > 0
      "https://farm#{flickraw.iconfarm}.staticflickr.com/#{flickraw.iconserver}/buddyicons/#{nsid}.jpg"
    else
      "https://www.flickr.com/images/buddyicon.gif"
    end
  end

  def photosurl
    flickraw.photosurl
  end
end

class License < Sequel::Model
  one_to_many :photos
  unrestrict_primary_key

  def icon
    case url
    when %r{/by-nc-sa/}
      '<i class="cc cc-cc"></i><i class="cc cc-by"></i><i class="cc cc-nc"></i><i class="cc cc-sa"></i>'
    when %r{/by-nc/}
      '<i class="cc cc-cc"></i><i class="cc cc-by"></i><i class="cc cc-nc"></i>'
    when %r{/by-nc-nd/}
      '<i class="cc cc-cc"></i><i class="cc cc-by"></i><i class="cc cc-nc"></i><i class="cc cc-nd"></i>'
    when %r{/by/}
      '<i class="cc cc-cc"></i><i class="cc cc-by"></i>'
    when %r{/by-sa/}
      '<i class="cc cc-cc"></i><i class="cc cc-by"></i><i class="cc cc-sa"></i>'
    when %r{/by-nd/}
      '<i class="cc cc-cc"></i><i class="cc cc-by"></i><i class="cc cc-nd"></i>'
    when %r{/commons/}, %r{/mark/}
      '<i class="cc cc-pd-alt"></i>'
    when %r{/zero/}
      '<i class="cc cc-zero"></i>'
    else
      '©'
    end
  end

  def icon_name
    icon + ' ' + name
  end

  def as_json(*)
    {
      id: id,
      name: name,
      url: url,
      icon: icon,
      iconname: icon_name,
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
      public: public,
      friend: friend,
      family: family,
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
    info = OpenStruct.new(flickr.people.getInfo(user_id: user.nsid).to_hash)
    info.timezone = info.timezone.to_hash
    info.photos = info.photos.to_hash
    user.json = info.to_h.to_json
    user.show_license = nil
    user.show_privacy = :all
    user.show_ignored = true
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
  @show_privacies = {
    all: 'show public and private photos',
    public: 'show only public photos',
    friends_family: 'show photos visible to friends and family',
    friends: 'show photos visible to only friends',
    family: 'show photos visible to only family',
    private: 'show completely private photos',
  }
  @show_ignoreds = {
    true => 'show ignored photos',
    false => 'hide ignored photos',
  }
  erb :index
end

get '/logout' do
  flickr_clear
  redirect to('/')
end

get %r{/photos/([1-8])} do |page|
  @user.photos_dataset.delete if params['reload'] == 'true'
  page, per_page = page.to_i, 500
  photos = @user.photos_dataset.reverse(:id).limit(per_page, (page - 1) * per_page).all
  begin
    photos = flickr.photos.search(user_id: :me, extras: 'license', per_page: per_page, page: page).map do |flickr_photo|
      Photo.create do |photo|
        photo.id = flickr_photo.id
        photo.user = @user
        photo.license_id = flickr_photo.license
        photo.json = flickr_photo.to_hash.to_json
        photo.ignore = false
        photo.public = flickr_photo.ispublic != 0
        photo.friend = flickr_photo.isfriend != 0
        photo.family = flickr_photo.isfamily != 0
      end
    end if photos.count == 0
  rescue FlickRaw::Error => e
    halt 422, json(error: e.message)
  rescue Sequel::UniqueConstraintViolation
    # sometimes the Flickr API will just keep repeating the same results for subsequent pages
  end
  halt json path: "/photos/#{page + 1}", photos: photos if photos.count == per_page && page < 8
  json photos: photos
end

post '/user' do
  halt 422, json(error: 'Missing required parameter(s)') unless %w(show_license show_privacy show_ignored).any? {|param| params[param]}
  show_license_id = params['show_license']
  if show_license_id
    if show_license_id.empty?
      show_license = nil
    else
      show_license_id = show_license_id.to_i
      show_license = License[show_license_id]
      halt 422, json(error: "Could not find license with ID: #{show_license_id.inspect}") unless show_license
    end
    @user.show_license = show_license
    @user.save
  end
  show_privacy = params['show_privacy']
  if show_privacy
    @user.show_privacy = show_privacy
    begin
      @user.save
    rescue Sequel::NotNullConstraintViolation
      halt 422, json(error: "Invalid privacy value: #{show_privacy.inspect}")
    end
  end
  show_ignored = params['show_ignored']
  if show_ignored
    @user.show_ignored = show_ignored == 'true'
    @user.save
  end
  status 204
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
  case @user.show_privacy
  when :all
    # no need to check privacy
  when :public
    halt 422, json(error: 'Could not change license of non public photo') unless photo.public
  when :friends_family
    halt 422, json(error: 'Could not change license of non friends and family photo') unless photo.friend && photo.family
  when :friends
    halt 422, json(error: 'Could not change license of non only friends photo') unless photo.friend && !photo.family
  when :family
    halt 422, json(error: 'Could not change license of non only family photo') unless !photo.friend && photo.family
  when :private
    halt 422, json(error: 'Could not change license of non private photo') unless !photo.public && !photo.friend && !photo.family
  end
  halt 422, json(error: 'Could not change license of photo with unselected license') if @user.show_license && @user.show_license != photo.license
  halt 422, json(error: 'Could not change license of ignored photo') if photo.ignore
  begin
    flickr.photos.licenses.setLicense(photo_id: photo.id, license_id: license.id)
  rescue FlickRaw::Error => e
    halt 422, json(error: e.message)
  end
  photo.update(license: license)
  status 204
end
