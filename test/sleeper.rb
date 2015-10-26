require 'rubygems'
require 'sinatra'
set :port, 3070

get '*' do
  sleep 30
end

post '*' do
  sleep 30
end
