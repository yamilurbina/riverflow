require 'rubygems'
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

require 'app.rb'

run Sinatra::Application

