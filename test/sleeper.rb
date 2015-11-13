require 'rubygems'
require 'sinatra'
set :port, 3070

get '*' do
  puts "#{ request.env }"
  sleep 30
end

post '*' do
  puts "#{ request.env }"
  sleep 30
end
