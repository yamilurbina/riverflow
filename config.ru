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

require 'app.rb'

run Sinatra::Application

