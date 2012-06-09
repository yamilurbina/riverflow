require 'sinatra'
require 'sinatra/session'
require 'sinatra/flash'
require 'sinatra/redirect_with_flash'
require 'redis'
require 'curb'
require 'haml'
require 'bcrypt'
require 'postmark'
require 'mail'

# XSS protection
helpers do
	include Rack::Utils
	alias_method :h, :escape_html	
end

set :session_fail, '/login'
set :session_secret, 'r1v3rf10W!'
set :session_name, 'riverflow'

redis = Redis.new

# Global variables
$address = 'riverflow.in'
$salt = '$2a$10$o9eRx9mLud4t4O5yOvRxne'
$postmark_api = "fb4075fb-6407-498f-a09e-46d8487f5793"
$invites_available = 3


#############################
########    Homepage  #######
#############################

get '/' do
	if session?
		@instances = redis.smembers "user:#{session['email']}:subdomains"
		@invites = redis.hget "user:#{session['email']}", "invites"
		@redis = redis
		@page_title = "Control Panel"
		haml :home
	else
		# if not, show the page that's gonna sell ;)
		@page_title = "BPM in the cloud"
		haml :alternate
	end
end

#############################
# Instances and Workspaces ##
#############################
post '/instance/add' do
	session!

	title = h params['title']
	url = h params['url']

	# Validate if params are not empty
	if title.empty? or url.empty?
		redirect '/', :notice => 'Fill the title and the URL.'
	end

	if not (redis.hget "subdomains", url).nil?
		redirect '/', :error => 'That URL is taken.'
	end

	# Register the subdomain
	redis.hsetnx "subdomains", url, session[:email]
	redis.hsetnx "user:#{session['email']}:#{url}", "title", title
	redis.sadd "user:#{session['email']}:subdomains", url

	c = Curl::Easy.http_post("http://demo.riverflow.in/sysdemo/en/classic/services/riverflow",
			Curl::PostField.content('name', url),
			Curl::PostField.content('hash', 's0mRIdlKvI'))
	puts c.body_str
	
	redis.sadd "subdomain:#{url}", url
	redirect "/", :success => 'Instance created!.'
end

#############################
########    Login    #######
#############################

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
	email = h params['email']
	password = h params['password']

	# Validation
	if email.empty? and password.empty?
		redirect '/login', :alert => 'Fields cannot be empty.'
	end

	user = "user:#{email}"

	# Get all fields
	user_data = redis.hgetall user

	# Account exists?
	if user_data.empty?
		redirect '/login', :error => "That account doesn't exist."
	end

	# Hash it
	hash = BCrypt::Engine.hash_secret(password, $salt)

	# Check password
	if not user_data["password"] == hash
		redirect '/login', :error => 'Wrong credentials.'
	end

	# Login da user
	session_start!
	session[:name] = user_data["name"]
	session[:email] = email

	# Redirect to control panel
	redirect '/', :success => 'Welcome back!'
end

## Invitations ##
post '/invites/add' do
	session!
	email = h params[:email]

	if email.empty?
		redirect '/', :error => 'Email address cannot be blank.'
	end

	if redis.exists "user:#{email}"
		redirect '/', :error => 'That email is already registered.'
	end

	# Generate random string
	o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten;  
	string  =  (0..8).map{ o[rand(o.length)]  }.join;

	# Save invitation
	redis.hset "invites", string, email
	
	@uri = "http://#{$address}/invites/#{string}"
	@inviter = session[:name]
	
	# Send the invitation!
	message = Mail.new
	message.delivery_method(Mail::Postmark, :api_key => $postmark_api)
	message.from = "invites@riverflow.in"
	message.to = email
	message.subject = "You have been invited to Riverflow"
	message.content_type = "text/html"
	message.body = haml :email, :layout => false
	# Send it now
	message.deliver

	# Decrease email
	redis.hincrby "user:#{session['email']}", "invites", -1

	# Redirect
	redirect '/', :success => 'Invitation sent.'
end
	
get '/invites/:key' do
	if session?
		redirect '/', :warning => "You are already logged in."
	end

	@invite = h params[:key]
	@invite_email = redis.hget "invites", @invite
	if (@invite_email).nil?
		redirect '/', :error => "Wrong invitation."
	end

	@page_title = "Signup"
	haml :signup
end

post '/invites/:key' do
	if session?
		redirect '/', :warning => "You are already logged in."
	end

	invite = h params[:key]
	email = redis.hget "invites", invite
	if (email).nil?
		redirect '/', :error => "Wrong invitation."
	end

	name = h params[:name]
	password = params[:password]

	user = "user:#{email}"

	# Hash it
	hash = BCrypt::Engine.hash_secret(password, $salt)

	# Register the user
	redis.hsetnx user, "name", name
	redis.hsetnx user, "password", hash

	# Give the user number of invitations
	redis.hsetnx user, "invites", $invites_available

	# Login the user
	session_start!
	session[:name] = name
	session[:email] = email

	# Delete the invitation
	redis.hdel "invites", invite

	# Welcome the user
	redirect '/', :success => 'Enjoy Riverflow :)'
end


######## Logout #######
get '/logout' do
	session_end!
	redirect '/', :notice => 'Hope to see you soon!'
end
