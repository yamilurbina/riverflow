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

# New Relic
require 'newrelic_rpm'

# Config file in YAML format
config_file 'config/config.yml'

# Set a redis connection
redis = Redis.new

# Datamapper for everything Redis
DataMapper.setup(:default, {:adapter => 'redis'})

# start Models
class User
	include DataMapper::Resource
	property :id, Serial
	property :name, String, :length => 3..30, :required => true
	property :email, String, :index => true, :unique => true, :format => :email_address, :length => 4..40, :required => true
	# If user has been invited
	property :invitation, String, :index => true
	# Number of invites
	property :invites, Integer, :default => settings.invites_available
	# Resetting password?
	property :reset, String, :index => true
	property :password, String, :index => true, :length => 0..80
	property :created_at, DateTime, :default => Time.now
	# User has many instances
	has n, :instances
end

class Instance
	include DataMapper::Resource
	property :id, Serial
	property :name, String, :length => 3..30, :required => true
	property :address, String, :length => 5..30, :index => true, :unique => true
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
# Instance.create(:name => 'Master Workflow', :url => 'workflow', :user => user)
# redis.sadd('subdomains', 'workflow')
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
		@page_title = "Business Process Management in the cloud, no configuration or deploys"
		haml :alternate
	end
end

get '/starting' do
	session!
	@page_title = 'Getting Started'
	haml :starting
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
	name = h params[:settingName]
	password = params[:settingPassword]
	repassword = params[:repeatsettingPassword]

	u = User.first(:email => session[:email])
	u.name = name
	u.created_at = Time.now

	if not password.empty?
		puts 'Saving password'
		if password == repassword
			# Hash it
			hash = BCrypt::Engine.hash_secret(password, settings.salt)
			u.password = hash
		else
			redirect '/settings', :error => 'Passwords must match.'
		end
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

	@name = h params['title']
	@url = h params['url'].downcase

	@u = User.first(:email => session[:email])
	i = Instance.new(:name => @name, :url => @url, :user => @u)

	if not i.valid?
	  	redirect '/', :error => "The instance values are wrong or it's in use."
	end

	c = Curl::Easy.http_post(settings.api_address + "shore",
		Curl::PostField.content('name', @url),
		Curl::PostField.content('hash', settings.processmaker_hash))
	puts c.body_str

	redis.sadd('subdomains', @url)
	i.save

	# Send a notification telling the instance has been created.
	message = Mail.new
	message.delivery_method(Mail::Postmark, :api_key => settings.postmark_api)
	message.from = "yamil@riverflow.in"
	message.to = @u[:email]
	message.subject = "A new ProcessMaker instance has been created on Riverflow"
	message.content_type = "text/html"
	message.body = haml :instance, :layout => false
	# Send it now
	message.deliver

	redirect "/instances", :success => "Instance created! Check your email for more details."
end

get '/instance/delete/:id' do
	session!
	instance = Instance.first(:id => params[:id])
	url = instance[:url]
	address = instance[:address]
	
	if instance.nil? or not instance.user[:email] == session[:email]
		redirect '/', :error => "That instance id is incorrect."
	end

	instance.destroy
	redis.srem('subdomains', url)
	# Delete domain aswell 
	redis.hdel('domains', address)
	c = Curl::Easy.http_post(settings.api_address + "outShore",
		Curl::PostField.content('name', url),
		Curl::PostField.content('hash', settings.processmaker_hash))
	puts c.body_str
	redirect '/', :success => "Instance deleted."
end

post '/address/add/:id' do
	session!
	address = h params[:address]
	instance = Instance.first(:id => params[:id])
	instance.address = address

	if instance.valid?
		redis.hset('domains', address, instance[:url])
		instance.save
		redirect '/instances', :success => 'Domain added. Make sure you modify your domain records to complete this.'
	else
		redirect '/instances', :error => 'Something went wrong. Please check again.'
	end
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
	redirect '/instances', :success => 'Welcome back. Nice to see you :)'
end

## Invitations ##
post '/invites/add' do
	session!
	email = h params[:email]

	user = User.new
	user.name = 'Full Name'
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
	message.from = "yamil@riverflow.in"
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
	u = User.first(:invitation => key)

	if u.nil?
		redirect '/', :error => "Something went wrong. Try again."
	end

	name = params[:name]
	password = params[:password]

	# Hash it
	hash = BCrypt::Engine.hash_secret(password, settings.salt)

	u.name = name
	u.password = hash
	u.created_at = Time.now
	u.invitation = false

	if not u.valid?
		u.errors.each do |e|
			puts e
		end
		redirect "/invites/#{key}", :error => "Check your fields again."
	end

	u.save

	# Welcome the user
	redirect '/login', :success => 'Registered. Enjoy the service :)'
end

# Password forgotten
get '/i/forgot/my/password' do
	if session?
		redirect '/instances', :error => 'You are already logged in'
	else
		@page_title = "Reset your password"
		haml :forgotpassword
	end
end

post '/i/forgot/my/password' do
	if params[:email].empty?
		redirect '/i/forgot/my/password', :error => 'No email address?'
	end

	# get the user
	r = User.first(:email => params[:email])

	# user doesn't exist?
	if r.nil?
		redirect '/i/forgot/my/password', :error => 'That email address is not in use.'
	end

	# Send the reset email

	# Generate random string
	o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten;  
	string  =  (0..8).map{ o[rand(o.length)]  }.join;

	@uri = "http://#{settings.address}/reset/#{string}"
	@user = r.name			
	# Send the reset email!
	message = Mail.new
	message.delivery_method(Mail::Postmark, :api_key => settings.postmark_api)
	message.from = "yamil@riverflow.in"
	message.to = r.email
	message.subject = "Reset your password at Riverflow"
	message.content_type = "text/html"
	message.body = haml :reset, :layout => false
	# Send it now
	message.deliver

	# save the string
	r.reset = string
	r.save

	redirect '/', :success => 'Check your email for instructions.'
end

get '/reset/:reset' do
	if session?
		redirect '/', :error => 'You are already logged in.'
	end

	r = User.first(:reset => params[:reset])
	if r.nil?
		redirect '/', :error => 'Invalid reset key.'
	end

	@user = r
	@page_title = "Resetting your password"
	haml :resetting
end

post '/reset/:reset' do
	if session?
		redirect '/', :error => 'You are already logged in.'
	end

	r = User.first(:reset => params[:reset])
	if r.nil?
		redirect '/', :error => 'Invalid reset key.'
	end

	if params[:password] != params[:repassword]
		redirect "/reset/#{params[:reset]}", :error => 'Passwords must be the same.'
	end

	# Hash it
	hash = BCrypt::Engine.hash_secret(params[:password], settings.salt)
	r.password = hash

	if not r.valid?
		redirect "/reset/#{params[:reset]}", :error => 'Something went wrong. Try again'
	end

	r.reset = false

	r.save
	redirect '/login', :success => 'Your password has been changed.'
end

######## Logout #######
get '/logout' do
	session_end!
	redirect '/', :notice => 'Hope to see you soon!'
end