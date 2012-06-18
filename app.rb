# Riverflow: BPM in the Cloud
# by Yamil Urbina <yamilurbina@gmail.com>
# Copyright 2012
require 'rubygems'
require 'sinatra'
require 'sinatra/session'
require 'sinatra/config_file'
require 'sinatra/flash'
require 'sinatra/redirect_with_flash'
require 'dm-core'
require 'dm-validations'
require 'dm-redis-adapter'
require 'curb'
require 'haml'	
require 'bcrypt'
require 'postmark'
require 'mail'

# Config file in YAML format
config_file 'config.yml'

# Set a redis connection
redis = Redis.new

# Datamapper for everything Redis
DataMapper.setup(:default, {:adapter => 'redis'})

# start Models
class User
	include DataMapper::Resource
	property :id, Serial
	property :name, String, :length => 3..30
	property :email, String, :index => true, :unique => true, :format => :email_address, :length => 4..40, :required => true
	# If user has been invited
	property :invitation, String, :index => true, :unique => true
	# Number of invites
	property :invites, Integer, :default => settings.invites_available
	property :password, String, :length => 0..60
	property :created_at, DateTime, :default => Time.now
	# User has many instances
	has n, :instances
end

class Instance
	include DataMapper::Resource
	property :id, Serial
	property :name, String, :length => 3..30, :required => true
	property :url, String, :index => true, :length => 3..60, :unique => true, :required => true
	property :workspaces, Integer, :default => settings.workspaces_available
	property :created_at, DateTime, :default => Time.now
	# Instances belongs to a User
	belongs_to :user
	# has n, :workspaces
end

# class Workspace
# 	include DataMapper::Resource
# 	property :id, Serial
# 	property :name, String, :index => true, :length => 3..10, :required => true, :unique => true
# 	property :created_at, DateTime, :default => Time.now
# 	belongs_to :instance
# end

# end Models
DataMapper.finalize

# mypass = hash = BCrypt::Engine.hash_secret('sample', settings.salt)
# User.create(:name => 'Yamil', :email => "yamilurbina@gmail.com", :password => mypass)
# puts "First user Created"
# user = User.first(:email => 'yamilurbina@gmail.com')
# Instance.new(:name => 'Master Workflow', :url 'workflow', :user => user)
# puts 'Instance created.'


# XSS protection
helpers do
	include Rack::Utils
	alias_method :h, :escape_html	
end

# Session settings
set :session_fail, '/login'
set :session_secret, settings.session_secret
set :session_name, settings.session_name

# Homepage
get '/' do
	if session?
		redirect '/instances'
	else
		# if not, show the page that's gonna sell ;)
		@page_title = "BPM in the cloud"
		haml :alternate
	end
end

# Settings
get '/settings' do
	session!
	@page_title = 'Settings'
	@user = User.first(:email => session[:email])
	haml :settings
end

post '/settings' do
	session!
	name = h params[:name]
	email = h params[:email]
	password = h params[:password]
	repassword = h params[:repassword]

	u = User.first(:email => session[:email])
	u.name = name
	u.email = email
	u.created_at = Time.now
	u.raise_on_save_failure = false

	if password == repassword
		# Hash it
		hash = BCrypt::Engine.hash_secret(password, settings.salt)
		u.password = hash
	else
		redirect '/settings', :error => 'Passwords must match.'
	end

	if not u.valid?
		redirect '/', :error => 'Please check your changes.'
	end

	u.save
	session[:name] = name
	redirect '/instances', :success => 'Your changes were saved.'
end

# Instances
get '/instances' do
	session!
	@user = User.first(:email => session[:email])
	@page_title = "Control Panel"
	haml :home
end

#############################
# Instances and Workspaces ##
#############################
post '/instance/add' do
	session!

	name = h params['title']
	url = h params['url']

	u = User.first(:id => session[:id])
	i = Instance.new(:name => name, :url => url, :user => u)


	if not i.valid?
	  	redirect '/', :error => "The instance values are wrong or it's in use."
	end

	redis.sadd('subdomains', url)
	i.save

	c = Curl::Easy.http_post("http://workflow.riverflow.de/sysworkflow/en/classic/services/shore",
		Curl::PostField.content('name', url),
		Curl::PostField.content('hash', 's0mRIdlKvI'))
	puts c.body_str

	redirect "/instances", :success => "Instance created! Launch it by clicking the link next to the title."
end

get '/instance/delete/:id' do
	session!
	instance = Instance.first(:id => params[:id])
	url = instance[:url]
	
	if instance.nil? or not instance.user[:email] == session[:email]
		redirect '/', :error => "That instance id is incorrect."
	end

	instance.destroy
	redis.srem('subdomains', url)
	c = Curl::Easy.http_post("http://workflow.riverflow.de/sysworkflow/en/classic/services/outShore",
		Curl::PostField.content('name', url),
		Curl::PostField.content('hash', 's0mRIdlKvI'))
	puts c.body_str
	redirect '/', :success => "Instance deleted."
end

# Login 
get '/login' do
	if session?
		redirect '/', :notice => 'You are already logged in.'
	else
		@page_title = "Login"
		haml :login
	end
end

post '/login' do
	# Escape strings
	email = h params[:email]
	password = h params[:password]

	# empty?
	if email.empty? and password.empty?
		redirect '/login', :alert => 'Fields cannot be empty.'
	end

	# get user
	get_user = User.first(:email => email)

	# exists?
	if get_user.nil?
		redirect '/login', :error => "That account doesn't exist."
	end

	# Hash it
	hash = BCrypt::Engine.hash_secret(password, settings.salt)

	# Check password
	if not get_user[:password] == hash
		redirect '/login', :error => 'Wrong credentials.'
	end

	# Login da user
	session_start!
	session[:id] = get_user[:id]
	session[:name] = get_user[:name]
	session[:email] = get_user[:email]

	# Redirect to control panel
	redirect '/instances', :success => 'And you are back. Nice to see you :)'
end

## Invitations ##
post '/invites/add' do
	session!
	email = h params[:email]

	user = User.new
	user.email = email

	if not user.valid?
		redirect '/', :error => 'Probably that email is in use.'
	end

	# Generate random string
	o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten;  
	string  =  (0..8).map{ o[rand(o.length)]  }.join;

	user.invitation = string

	@uri = "http://#{settings.address}/invites/#{string}"
	@inviter = session[:name]			
	# Send the invitation!
	message = Mail.new
	message.delivery_method(Mail::Postmark, :api_key => settings.postmark_api)
	message.from = "invites@riverflow.in"
	message.to = email
	message.subject = "You have been invited to Riverflow"
	message.content_type = "text/html"
	message.body = haml :email, :layout => false
	# Send it now
	message.deliver

	user.created_at = Time.now

	# Reduce the user's invitation numbers
	inviter = User.first(:email, session[:email])
	inviter.invites = inviter[:invites] - 1
	inviter.save

	# Save the user
	user.save

	# Redirect
	redirect '/', :success => 'Invitation sent.'
end
	
get '/invites/:key' do
	if session?
		redirect '/', :warning => "You are already logged in."
	end

	# the key
	@invite = params[:key]

	details = User.first(:invitation => @invite)

	if details.nil?
		redirect '/', :error => "Invitation not valid or it has already been used."
	end

	@invite_email = details[:email]
	@page_title = "Signup"
	haml :signup
end

post '/invites/:key' do
	if session?
		redirect '/', :warning => "You are already logged in."
	end

	# the key
	key = params[:key]

	# Get the user based on email
	user = User.first(:invitation => key)

	if user.nil?
		redirect '/', :error => "Something went wrong. Try again."
	end

	name = h params[:name]
	password = params[:password]

	if name.empty? or password.empty?
		redirect '/', :error => "Check your field again"
	end

	# Hash it
	hash = BCrypt::Engine.hash_secret(password, settings.salt)

	# Register the user
	user.name = name
	user.password = hash
	user.created_at = Time.now

	if not user.valid?
		redirect '/invites/#{key}', :error => "Check your fields again."
	end

	user.invitation = false

	user.save

	# Login the user
	session_start!
	session[:name] = name
	session[:email] = user[:email]

	# Welcome the user
	redirect '/instances', :success => 'Welcome! Enjoy Riverflow :)'
end

######## Logout #######
get '/logout' do
	session_end!
	redirect '/', :notice => 'Hope to see you soon!'
end